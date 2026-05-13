// CollabWebBridge.swift — WKWebView ↔ Swift message bridge for the unified model.
// Note: CollabPanelView.swift has its own inline coordinator for the actual panel.
// This class provides the standalone bridge pattern for other use cases.

import Foundation
@preconcurrency import WebKit
import Combine

@MainActor
public final class CollabWebBridge: NSObject, WKScriptMessageHandler {
    private weak var webView: WKWebView?
    private let engine: CollabEngine
    private let identity: IdentityManager

    public let didMutate = PassthroughSubject<Void, Never>()

    public static let handlerNames = [
        "collabReply", "collabResolve", "collabAssign",
        "collabLabel", "collabNewComment", "collabRefresh"
    ]

    public init(engine: CollabEngine, identity: IdentityManager = .shared) {
        self.engine = engine
        self.identity = identity
        super.init()
    }

    public func attach(to webView: WKWebView) {
        self.webView = webView
        let controller = webView.configuration.userContentController
        for name in Self.handlerNames {
            controller.add(self, name: name)
        }
    }

    public func detach() {
        guard let webView else { return }
        let controller = webView.configuration.userContentController
        for name in Self.handlerNames {
            controller.removeScriptMessageHandler(forName: name)
        }
    }

    public func pushAnnotations() {
        guard let webView else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(engine.document.annotations),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("CollabBridge.receiveComments(\(json))")
    }

    public func pushTheme(_ theme: String) {
        webView?.evaluateJavaScript("CollabBridge.receiveTheme('\(theme)')")
    }

    public func pushUser() {
        webView?.evaluateJavaScript("CollabBridge.receiveUser('\(identity.alias)')")
    }

    // MARK: - WKScriptMessageHandler

    nonisolated public func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let body = message.body
        let name = message.name
        Task { @MainActor in
            guard let dict = body as? [String: Any] else { return }
            self.handleMessage(name: name, body: dict)
        }
    }

    private func handleMessage(name: String, body: [String: Any]) {
        switch name {
        case "collabReply":
            guard let id = body["commentId"] as? String,
                  let text = body["body"] as? String else { return }
            engine.reply(to: id, author: identity.alias, text: text)

        case "collabResolve":
            guard let id = body["commentId"] as? String else { return }
            engine.resolve(annotationID: id, by: identity.alias)

        case "collabAssign":
            guard let id = body["commentId"] as? String,
                  let assignee = body["assignee"] as? String else { return }
            engine.assign(annotationID: id, to: assignee)

        case "collabLabel":
            guard let id = body["commentId"] as? String,
                  let label = body["label"] as? String else { return }
            engine.addLabel(annotationID: id, label: label)

        case "collabNewComment":
            NotificationCenter.default.post(name: .collabNewCommentRequested, object: nil)

        default:
            break
        }

        didMutate.send()
        pushAnnotations()
    }
}

public extension Notification.Name {
    static let collabNewCommentRequested = Notification.Name("collabNewCommentRequested")
}
