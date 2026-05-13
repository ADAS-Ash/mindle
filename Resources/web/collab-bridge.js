// collab-bridge.js — Bidirectional bridge between the panel WKWebView and Swift.
// Outbound (JS → Swift): posts messages via webkit.messageHandlers.
// Inbound (Swift → JS): Swift calls these functions via evaluateJavaScript.
// Pattern: JS actions → Swift handler → engine mutation → Swift pushes updated state back.

// Debug utility — writes to the #debug-log element when the 🐛 toggle is active.
// Harmless no-op when the debug panel is hidden.
function dbg(msg) {
  const el = document.getElementById('debug-log');
  if (el) {
    const t = new Date().toLocaleTimeString('en-GB', {hour:'2-digit',minute:'2-digit',second:'2-digit'});
    el.innerHTML += `[${t}] ${msg}<br>`;
    el.scrollTop = el.scrollHeight;
  }
}

const CollabBridge = (() => {
  // Send message to Swift via webkit.messageHandlers
  function post(handler, payload) {
    dbg(`→ Swift: ${handler}`);
    if (window.webkit?.messageHandlers?.[handler]) {
      window.webkit.messageHandlers[handler].postMessage(payload);
    } else {
      console.log(`[CollabBridge] ${handler}:`, payload);
    }
  }

  // Outbound: JS → Swift
  function sendReply(commentId, author, body) {
    post("collabReply", { commentId, author, body });
  }

  function sendResolve(commentId, resolvedBy) {
    post("collabResolve", { commentId, resolvedBy });
  }

  function sendAssign(commentId, assignee) {
    post("collabAssign", { commentId, assignee });
  }

  function sendLabel(commentId, label) {
    post("collabLabel", { commentId, label });
  }

  function requestNewComment() {
    post("collabNewComment", {});
  }

  function sendRefresh() {
    post("collabRefresh", {});
  }

  function requestIdentityChange() {
    post("collabIdentityChange", {});
  }

  function scrollToAnchor(anchor) {
    post("collabScrollToAnchor", anchor);
  }

  function scrollPanelToComment(commentId) {
    const card = document.querySelector(`.comment-card[data-id="${commentId}"]`);
    if (card) card.scrollIntoView({ behavior: "smooth", block: "center" });
  }

  // Inbound: Swift → JS (called via evaluateJavaScript)
  function receiveComments(json) {
    const data = typeof json === "string" ? JSON.parse(json) : json;
    dbg(`← Swift: receiveComments (${Array.isArray(data) ? data.length : '?'} items)`);
    CollabPanel.setComments(data);
    CollabHighlights.applyHighlights(data);
  }

  function receiveTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme);
  }

  function receiveUser(user) {
    dbg(`← Swift: receiveUser('${user}')`);
    CollabPanel.init(user);
  }

  // Expose inbound API globally for evaluateJavaScript calls
  window.CollabBridge = {
    sendReply,
    sendResolve,
    sendAssign,
    sendLabel,
    requestNewComment,
    sendRefresh,
    requestIdentityChange,
    scrollToAnchor,
    scrollPanelToComment,
    receiveComments,
    receiveTheme,
    receiveUser,
  };

  return window.CollabBridge;
})();
