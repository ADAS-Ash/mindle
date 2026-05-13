// MarkCollab — Inline Highlight Overlays for the Markdown Pane

const CollabHighlights = (() => {
  const HIGHLIGHT_CLASS = "collab-highlight";
  let activeHighlights = [];

  function applyHighlights(comments) {
    clearHighlights();
    comments.filter(c => c.status === "open").forEach(c => {
      const range = findAnchorRange(c.anchor);
      if (range) highlight(range, c);
    });
  }

  function clearHighlights() {
    activeHighlights.forEach(el => {
      const parent = el.parentNode;
      if (parent) {
        parent.replaceChild(document.createTextNode(el.textContent), el);
        parent.normalize();
      }
    });
    activeHighlights = [];
  }

  function highlight(range, comment) {
    const mark = document.createElement("mark");
    mark.className = HIGHLIGHT_CLASS;
    mark.dataset.commentId = comment.id;
    mark.style.backgroundColor = (comment._color || "#4A90D9") + "33";
    mark.style.borderBottom = `2px solid ${comment._color || "#4A90D9"}`;
    mark.style.cursor = "pointer";
    mark.title = `${comment.thread?.[0]?.author}: ${comment.thread?.[0]?.body?.slice(0, 50) || ""}`;
    mark.onclick = () => CollabBridge.scrollPanelToComment(comment.id);

    try {
      range.surroundContents(mark);
      activeHighlights.push(mark);
    } catch {
      // Range crosses element boundaries; fall back to simple insert
      const fragment = range.extractContents();
      mark.appendChild(fragment);
      range.insertNode(mark);
      activeHighlights.push(mark);
    }
  }

  function scrollToAnchor(anchor) {
    const mark = document.querySelector(`[data-comment-id="${anchor._commentId || ""}"]`);
    if (mark) {
      mark.scrollIntoView({ behavior: "smooth", block: "center" });
      mark.style.transition = "background-color 0.3s";
      mark.style.backgroundColor = (anchor._color || "#4A90D9") + "66";
      setTimeout(() => { mark.style.backgroundColor = (anchor._color || "#4A90D9") + "33"; }, 1500);
      return;
    }
    // Fallback: text search
    const range = findAnchorRange(anchor);
    if (range) {
      const el = range.startContainer.parentElement;
      if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }

  function findAnchorRange(anchor) {
    if (!anchor?.text) return null;
    const body = document.body;
    const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT);
    const searchText = (anchor.prefix || "") + anchor.text + (anchor.suffix || "");

    let node;
    let fullText = "";
    const nodes = [];

    while ((node = walker.nextNode())) {
      nodes.push({ node, start: fullText.length });
      fullText += node.textContent;
    }

    // Find the anchor text within the full document text
    const prefixLen = (anchor.prefix || "").length;
    const idx = fullText.indexOf(anchor.text);
    if (idx === -1) return null;

    const startOffset = idx;
    const endOffset = idx + anchor.text.length;

    const startNode = nodes.find((n, i) => {
      const next = nodes[i + 1];
      return startOffset >= n.start && (!next || startOffset < next.start);
    });
    const endNode = nodes.find((n, i) => {
      const next = nodes[i + 1];
      return endOffset > n.start && (!next || endOffset <= next.start);
    });

    if (!startNode || !endNode) return null;

    const range = document.createRange();
    range.setStart(startNode.node, startOffset - startNode.start);
    range.setEnd(endNode.node, endOffset - endNode.start);
    return range;
  }

  return { applyHighlights, clearHighlights, scrollToAnchor };
})();
