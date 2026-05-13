// CollabPanelView.swift — NSViewRepresentable hosting the comment panel WKWebView.
// Loads collab-panel.html and bridges user actions (reply, resolve, assign, etc.)
// back to CollabEngine. Uses a polling approach via collabRevision because
// SwiftUI's updateNSView doesn't reliably fire after NSAlert.runModal() blocks.
// The Coordinator owns the WKWebView lifecycle and pushes data on revision changes.

import SwiftUI
import WebKit

struct CollabPanelView: NSViewRepresentable {
    @EnvironmentObject var store: DocumentStore

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        for name in ["collabReply", "collabResolve", "collabAssign", "collabLabel", "collabNewComment", "collabRefresh", "collabScrollToAnchor"] {
            userContent.add(context.coordinator, name: name)
        }
        config.userContentController = userContent
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.setValue(false, forKey: "drawsBackground")
        context.coordinator.web = web
        context.coordinator.storeRef = store

        if let html = Bundle.main.url(forResource: "collab-panel", withExtension: "html", subdirectory: "web") {
            web.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        }
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        let coord = context.coordinator
        guard coord.loaded else { return }

        // Trigger on collabRevision changes
        let rev = store.collabRevision
        if rev != coord.lastRevision {
            coord.lastRevision = rev
            coord.pushAll()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var web: WKWebView?
        weak var storeRef: DocumentStore?
        var loaded = false
        var lastRevision = -1

        func pushAll() {
            guard let web, let store = storeRef else { return }
            let collabs = store.collabCollaboratorsJSON
            web.evaluateJavaScript("CollabPanel.setCollaborators(\(collabs));")
            let json = store.collabCommentsJSON
            web.evaluateJavaScript("CollabBridge.receiveComments(\(json));")
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            guard let store = storeRef else { return }

            let alias = IdentityManager.shared.alias
            webView.evaluateJavaScript("CollabBridge.receiveUser('\(alias)');")
            webView.evaluateJavaScript("CollabBridge.receiveTheme('\(store.theme.rawValue)');")
            pushAll()
            lastRevision = store.collabRevision
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let store = storeRef else { return }
            let engine = store.collabEngine

            switch message.name {
            case "collabReply":
                guard let cid = body["commentId"] as? String,
                      let text = body["body"] as? String else { return }
                engine.reply(to: cid, author: IdentityManager.shared.alias, text: text)

            case "collabResolve":
                guard let cid = body["commentId"] as? String else { return }
                engine.resolve(annotationID: cid, by: IdentityManager.shared.alias)

            case "collabAssign":
                guard let cid = body["commentId"] as? String,
                      let assignee = body["assignee"] as? String else { return }
                engine.assign(annotationID: cid, to: assignee)

            case "collabLabel":
                guard let cid = body["commentId"] as? String,
                      let label = body["label"] as? String else { return }
                engine.addLabel(annotationID: cid, label: label)

            case "collabNewComment":
                // Snapshot selection NOW before focus change clears it
                let selText = store.selectionText
                let selPrefix = store.selectionPrefix
                let selSuffix = store.selectionSuffix
                guard !selText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    NSSound.beep()
                    return
                }
                let alert = NSAlert()
                alert.messageText = "New Comment"
                alert.informativeText = "On: \"\(selText.prefix(60))\""
                alert.addButton(withTitle: "Add")
                alert.addButton(withTitle: "Cancel")
                let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
                input.placeholderString = "Your comment…"
                alert.accessoryView = input
                alert.window.initialFirstResponder = input
                if alert.runModal() == .alertFirstButtonReturn {
                    let body = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !body.isEmpty {
                        let anchor = TextAnchor(
                            text: selText,
                            prefix: String(selPrefix.suffix(48)),
                            suffix: String(selSuffix.prefix(48))
                        )
                        engine.addAnnotation(anchor: anchor, author: IdentityManager.shared.alias, text: body)
                        try? engine.save()
                        store.collabRevision += 1
                        pushAll()
                    }
                }
                return

            case "collabRefresh":
                if let url = store.fileURL {
                    try? engine.load(for: url)
                }

            case "collabScrollToAnchor":
                // Tell the reader WebView to scroll to this anchor text
                guard let text = body["text"] as? String else { return }
                let jsText = text.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                NotificationCenter.default.post(
                    name: Notification.Name("collabScrollReader"),
                    object: nil,
                    userInfo: ["js": "window.mindleScrollToText('\(jsText)')"]
                )
                return

            default:
                return
            }

            // Save and refresh panel
            try? engine.save()
            store.collabRevision += 1
            pushAll()
        }
    }
}
