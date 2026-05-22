import SwiftUI
import AppKit

/// A multi-line text editor backed directly by `NSTextView`. Unlike
/// SwiftUI's `TextEditor`, this view owns its `NSTextView` instance for
/// the lifetime of the SwiftUI view and does not relinquish first
/// responder on parent re-renders.
///
/// Why this exists: the annotation sidebar's `ForEach(store.annotations)`
/// re-renders every card any time any annotation mutates (because
/// `@EnvironmentObject store` fires on any `@Published` change). With a
/// stock `TextEditor` + `@FocusState`, those sibling-driven re-renders
/// can drop first responder mid-keystroke — the user reports "Mac
/// beeps as I type while the agent posts on another annotation." This
/// view's `updateNSView` is idempotent at the AppKit level: it only
/// pushes a change to the text view when state actually differs, and
/// it never resigns first responder on its own.
///
/// Behavior:
/// - Return commits via `onCommit`.
/// - Shift+Return inserts a literal newline (the multi-line case).
/// - Text changes flow back via the `text` binding.
struct FocusStableTextEditor: NSViewRepresentable {
    @Binding var text: String
    /// One-way: when this transitions from false to true, we ask the
    /// window to make our text view the first responder. We never
    /// resign on our own — only the user clicking elsewhere or another
    /// view explicitly stealing focus removes it.
    @Binding var isFocused: Bool
    let font: NSFont
    let textColor: NSColor
    let onCommit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = CommittingTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = font
        textView.textColor = textColor
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.onCommit = { [weak coord = context.coordinator] in
            coord?.parent.onCommit()
        }
        // When the user clicks anywhere else (another card, the
        // article, the file browser), AppKit takes first responder
        // away from this text view. Push that back into the binding
        // so updateNSView doesn't try to re-grab focus on the next
        // store change. Without this, isFocused stays stuck at true
        // and any sibling re-render yanks the cursor back to this
        // textbox.
        textView.onResignFocus = { [weak coord = context.coordinator] in
            DispatchQueue.main.async {
                coord?.parent.isFocused = false
            }
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CommittingTextView else { return }
        // Refresh the coordinator's closure-bearing parent so the latest
        // onCommit captures the latest state.
        context.coordinator.parent = self

        // Only mutate the text view's contents if they actually differ.
        // Setting `string` blows away selection and undo state, so
        // skipping the no-op case is what keeps typing smooth across
        // sibling re-renders.
        if textView.string != text {
            textView.string = text
        }
        if textView.font != font {
            textView.font = font
        }
        if textView.textColor != textColor {
            textView.textColor = textColor
        }

        // Push first responder only on the rising edge of isFocused.
        // We never call resignFirstResponder ourselves — AppKit handles
        // resignation via user action, and a spurious SwiftUI re-render
        // setting isFocused=false momentarily must not yank focus.
        if isFocused, let window = textView.window, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: FocusStableTextEditor
        weak var textView: NSTextView?

        init(parent: FocusStableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

/// Read-only, selectable, word-wrapping text label. Backed by
/// `NSTextField` so text-selection actually works inside the annotation
/// sidebar — SwiftUI's `Text(...).textSelection(.enabled)` is unreliable
/// here because the parent `ForEach(store.annotations)` rebuilds every
/// card on any store mutation, dropping the in-flight selection.
/// Same root cause `FocusStableTextEditor` exists for.
struct SelectableText: NSViewRepresentable {
    let text: String
    let font: NSFont
    let textColor: NSColor
    /// 0 = unlimited (full wrap). N>0 clamps height to N line-heights and
    /// truncates with a tail ellipsis.
    var maxLines: Int = 0

    func makeNSView(context: Context) -> SelectableTextHostView {
        let host = SelectableTextHostView()
        host.maxLines = maxLines
        host.configure(text: text, font: font, textColor: textColor)
        return host
    }

    func updateNSView(_ host: SelectableTextHostView, context: Context) {
        if host.maxLines != maxLines {
            host.maxLines = maxLines
        }
        host.configure(text: text, font: font, textColor: textColor)
    }

    /// macOS 13+ sizing hook. SwiftUI calls this to ask "for this proposed
    /// width, how much height do you need?" before the first layout pass.
    /// Without this override SwiftUI relies on intrinsicContentSize, which
    /// is queried *before* `layout()` runs — so on first render the host
    /// reports a one-line height (bounds.width is still 0), SwiftUI lays
    /// the siblings beneath that height, and the actual multi-line text
    /// then renders into the same Y range as the next sibling. The
    /// symptom is annotation-card buttons rendering *behind* a wrapped
    /// body. Computing the wrap-aware height here closes the gap.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SelectableTextHostView, context: Context) -> CGSize? {
        let width = proposal.width ?? nsView.bounds.width
        guard width > 0 else { return nil }
        let height = nsView.measureHeight(forWidth: width)
        return CGSize(width: width, height: height)
    }
}

/// AppKit container that owns a non-editable, selectable `NSTextView` and
/// computes a wrap-aware `intrinsicContentSize` so SwiftUI can lay it out
/// as a self-sizing block. We can't use a bare `NSTextView` here because
/// it doesn't expose a wrap-aware intrinsic size — SwiftUI proposes a
/// width that the text view doesn't read, so it lays out at zero height.
/// We can't use the `FocusStableTextEditor` `NSScrollView` wrapping
/// either, because nesting an `NSScrollView` inside SwiftUI's `ScrollView`
/// fights drag gestures with the outer scroller.
final class SelectableTextHostView: NSView {
    private let textView = NSTextView()
    var maxLines: Int = 0 {
        didSet { invalidateIntrinsicContentSize() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        // Both resize axes must be off. With isVerticallyResizable=true,
        // an NSTextView that finds itself with insufficient frame height
        // inside drawRect calls _resizeTextViewForTextContainer → setFrameSize.
        // setFrameSize fires constraint updates which SwiftUI's host turns
        // into a LayoutInvalidator.invalidate() — and AppKit panics on
        // "constraint change during draw," crashing the app with
        // EXC_BREAKPOINT. The host (SelectableTextHostView) is the only
        // authority on height — sizeThatFits and intrinsicContentSize
        // report the wrap-aware value; the text view just fills the frame
        // we give it.
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.autoresizingMask = []
        // Safety net: the maxLines clamp computes the bottom of the Nth
        // line precisely (see measureHeight), but if the layout manager
        // and the host ever disagree by a pixel — or if NSTextView paints
        // a fragment outside the dirty rect we asked for — clipping the
        // host's bounds keeps overflow from bleeding into the action row
        // beneath the annotation card body.
        self.clipsToBounds = true
        addSubview(textView)
    }

    func configure(text: String, font: NSFont, textColor: NSColor) {
        if textView.string != text {
            textView.string = text
        }
        if textView.font != font {
            textView.font = font
        }
        if textView.textColor != textColor {
            textView.textColor = textColor
        }
        invalidateIntrinsicContentSize()
    }

    override func layout() {
        super.layout()
        textView.frame = bounds
        textView.textContainer?.size = NSSize(
            width: bounds.width,
            height: .greatestFiniteMagnitude
        )
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        let height = measureHeight(forWidth: bounds.width)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    /// Lay the text out at `width` and report the wrap-aware height,
    /// clamped to `maxLines` when set. Shared between
    /// `intrinsicContentSize` (the older path, called when bounds.width
    /// is meaningful) and `SelectableText.sizeThatFits` (the macOS 13+
    /// path, called with SwiftUI's proposed width before layout runs).
    ///
    /// Clamping walks actual line fragments from the layout manager
    /// rather than multiplying `defaultLineHeight` by the line count —
    /// the typographic line height ignores inter-line spacing that
    /// NSTextView applies during real layout, so the multiplier always
    /// undercounted on wrapped bodies and the action row beneath the
    /// host ended up painted-over.
    func measureHeight(forWidth width: CGFloat) -> CGFloat {
        guard let lm = textView.layoutManager,
              let tc = textView.textContainer else {
            return 0
        }
        tc.size = NSSize(
            width: max(width, 1),
            height: .greatestFiniteMagnitude
        )
        lm.ensureLayout(for: tc)
        let full = lm.usedRect(for: tc).height
        if maxLines <= 0 {
            return ceil(full)
        }
        // Walk line fragments until we've passed maxLines; the bottom of
        // the Nth fragment is the precise clamp height. If the text has
        // fewer than maxLines lines, we keep the full height.
        var lineCount = 0
        var clampedHeight: CGFloat = full
        let glyphRange = NSRange(location: 0, length: lm.numberOfGlyphs)
        lm.enumerateLineFragments(forGlyphRange: glyphRange) { _, used, _, _, stop in
            lineCount += 1
            if lineCount >= self.maxLines {
                clampedHeight = used.maxY
                stop.pointee = true
            }
        }
        return ceil(min(full, clampedHeight))
    }
}

/// NSTextView subclass that routes bare Return through a commit
/// closure instead of inserting a newline. Shift+Return inserts a real
/// newline (the multi-line case).
final class CommittingTextView: NSTextView {
    var onCommit: (() -> Void)?
    /// Fired when this text view loses first-responder status. The
    /// SwiftUI binding for isFocused needs to reflect AppKit reality,
    /// otherwise updateNSView keeps trying to re-grab focus.
    var onResignFocus: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        if isReturn {
            if event.modifierFlags.contains(.shift) {
                insertText("\n", replacementRange: selectedRange())
                return
            }
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            onResignFocus?()
        }
        return didResign
    }
}
