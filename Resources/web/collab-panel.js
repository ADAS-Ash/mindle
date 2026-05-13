// collab-panel.js — Comment panel rendering and interaction logic.
// Receives comment data from Swift (via CollabBridge.receiveComments), renders
// threaded comment cards, handles user actions (reply, resolve, assign, label),
// and sends mutations back to Swift via webkit.messageHandlers.
// Sections: init, data ingestion, rendering, card actions, filtering, helpers.

const CollabPanel = (() => {
  let comments = [];
  let currentFilter = "all";
  let currentSort = "newest";
  let currentUser = "anonymous";

  const el = (sel) => document.querySelector(sel);

  function init(user) {
    dbg('panel.init: ' + user);
    currentUser = user || "anonymous";
    bindFilter();
    bindSort();
    bindResize();
    bindFAB();
  }

  function setComments(data) {
    dbg('panel.setComments: ' + (data||[]).length + ' items');
    comments = data || [];
    render();
  }

  function render() {
    dbg('panel.render: ' + comments.length + ' total');
    const list = el(".collab-panel__list");
    const filtered = sortComments(filterComments(comments));
    const openCount = comments.filter(c => c.status === "open").length;

    el(".collab-panel__title").textContent = `Comments (${openCount} open)`;

    if (filtered.length === 0) {
      list.innerHTML = `<div class="collab-panel__empty">No comments yet.<br>Select text and press ⌘⇧C to start.</div>`;
      return;
    }

    list.innerHTML = filtered.map(renderCard).join("");
    bindCardActions();
  }

  function filterComments(list) {
    switch (currentFilter) {
      case "open": return list.filter(c => c.status === "open");
      case "resolved": return list.filter(c => c.status === "resolved");
      case "mine": return list.filter(c => c.assignee === currentUser);
      default: return list;
    }
  }

  function renderCard(comment) {
    const statusClass = `status-pill--${comment.status}`;
    const anchorText = (comment.anchor?.text || "").slice(0, 60);
    const labels = (comment.labels || []).map(l => `<span class="label-pill">${esc(l)}</span>`).join("");
    const assignee = comment.assignee ? `<span class="assignee-badge">→ ${esc(comment.assignee)}</span>` : "";
    const thread = (comment.thread || []).map(renderReply).join("");

    const headerTime = fmtTime(threadTime(comment));

    return `
      <div class="comment-card" data-id="${esc(comment.id)}">
        <div class="comment-card__header">
          <span class="comment-card__dot" style="background:${authorColor(threadAuthor(comment))}"></span>
          <span class="comment-card__author">${esc(threadAuthor(comment))}</span>
          <span class="${statusClass} status-pill">${comment.status}</span>
          ${headerTime ? `<span class="comment-card__time">· ${headerTime}</span>` : ""}
        </div>
        <div class="comment-card__anchor" data-anchor='${esc(JSON.stringify(comment.anchor))}'>${esc(anchorText)}</div>
        <div class="comment-card__meta">${assignee}${labels}</div>
        <div class="comment-card__thread">${thread}</div>
        <div class="comment-card__reply-box">
          <textarea placeholder="Reply…" rows="1"></textarea>
          <button data-action="reply" data-id="${esc(comment.id)}">Reply</button>
        </div>
        <div class="comment-card__actions">
          <button data-action="resolve" data-id="${esc(comment.id)}">Resolve</button>
          <button data-action="assign" data-id="${esc(comment.id)}">Assign ▾</button>
          <button data-action="labels" data-id="${esc(comment.id)}">Labels ▾</button>
        </div>
      </div>`;
  }

  function renderReply(reply) {
    // Handle both old format (body/timestamp) and new unified format (text/createdAt)
    const time = fmtTime(reply.timestamp || reply.createdAt);
    return `
      <div class="reply">
        <div class="reply__header">
          <span class="comment-card__dot" style="background:${authorColor(reply.author)}"></span>
          <span class="reply__author">${esc(reply.author)}</span>
          ${time ? `<span class="reply__time">· ${time}</span>` : ""}
        </div>
        <div class="reply__body">${esc(reply.body || reply.text)}</div>
      </div>`;
  }

  function bindCardActions() {
    document.querySelectorAll("[data-action='reply']").forEach(btn => {
      btn.onclick = () => {
        const card = btn.closest(".comment-card");
        const textarea = card.querySelector("textarea");
        const body = textarea.value.trim();
        if (!body) return;
        textarea.value = "";
        CollabBridge.sendReply(card.dataset.id, currentUser, body);
      };
    });

    document.querySelectorAll("[data-action='resolve']").forEach(btn => {
      btn.onclick = () => CollabBridge.sendResolve(btn.dataset.id, currentUser);
    });

    document.querySelectorAll("[data-action='assign']").forEach(btn => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const names = Object.keys(collaborators);
        if (names.length === 0) {
          const name = prompt("Assign to:");
          if (name) CollabBridge.sendAssign(btn.dataset.id, name);
        } else {
          showDropdown(btn, names, (name) => CollabBridge.sendAssign(btn.dataset.id, name));
        }
      };
    });

    document.querySelectorAll("[data-action='labels']").forEach(btn => {
      btn.onclick = (e) => {
        e.stopPropagation();
        showDropdown(btn, ["question", "blocker", "nit", "todo", "suggestion"], (label) => {
          CollabBridge.sendLabel(btn.dataset.id, label);
        });
      };
    });

    document.querySelectorAll(".comment-card__anchor").forEach(anchor => {
      anchor.onclick = () => {
        const data = JSON.parse(anchor.dataset.anchor);
        CollabBridge.scrollToAnchor(data);
      };
    });
  }

  function bindFilter() {
    const select = el(".collab-panel__filter");
    if (!select) return;
    select.onchange = () => {
      currentFilter = select.value;
      render();
    };
    const refresh = el(".collab-panel__refresh");
    if (refresh) {
      refresh.onclick = () => { dbg('CLICK: refresh'); CollabBridge.sendRefresh(); };
    }
  }

  function bindSort() {
    const select = el(".collab-panel__sort");
    if (!select) return;
    select.onchange = () => {
      currentSort = select.value;
      render();
    };
  }

  function sortComments(list) {
    switch (currentSort) {
      case "newest":
        return [...list].sort((a, b) => {
          const ta = a.createdAt || a.thread?.[0]?.createdAt || a.thread?.[0]?.timestamp || "";
          const tb = b.createdAt || b.thread?.[0]?.createdAt || b.thread?.[0]?.timestamp || "";
          return tb.localeCompare(ta);
        });
      case "oldest":
        return [...list].sort((a, b) => {
          const ta = a.createdAt || a.thread?.[0]?.createdAt || a.thread?.[0]?.timestamp || "";
          const tb = b.createdAt || b.thread?.[0]?.createdAt || b.thread?.[0]?.timestamp || "";
          return ta.localeCompare(tb);
        });
      case "position":
        return [...list].sort((a, b) => (a.anchor?.prefix || "").localeCompare(b.anchor?.prefix || ""));
      default:
        return list;
    }
  }

  function bindResize() {
    const handle = el(".collab-panel__resize");
    const panel = el(".collab-panel");
    if (!handle || !panel) return;

    let startX, startW;
    handle.onmousedown = (e) => {
      startX = e.clientX;
      startW = panel.offsetWidth;
      handle.classList.add("active");
      const onMove = (e2) => {
        const diff = startX - e2.clientX;
        panel.style.width = Math.max(240, Math.min(600, startW + diff)) + "px";
      };
      const onUp = () => {
        handle.classList.remove("active");
        document.removeEventListener("mousemove", onMove);
        document.removeEventListener("mouseup", onUp);
      };
      document.addEventListener("mousemove", onMove);
      document.addEventListener("mouseup", onUp);
    };
  }

  function bindFAB() {
    const fab = el(".collab-panel__fab-inline");
    if (!fab) return;
    fab.onclick = () => { dbg('CLICK: +FAB'); CollabBridge.requestNewComment(); };
  }

  // Dropdown menu for assign/labels
  function showDropdown(anchor, items, onSelect) {
    const existing = document.querySelector('.collab-dropdown');
    if (existing) existing.remove();
    const menu = document.createElement('div');
    menu.className = 'collab-dropdown';
    menu.style.cssText = 'position:absolute;z-index:9999;background:var(--card-bg);border:1px solid var(--border);border-radius:6px;padding:4px 0;box-shadow:0 4px 12px var(--shadow);min-width:120px;';
    const rect = anchor.getBoundingClientRect();
    menu.style.top = (rect.bottom + 4) + 'px';
    menu.style.left = rect.left + 'px';
    items.forEach(item => {
      const opt = document.createElement('div');
      opt.textContent = item;
      opt.style.cssText = 'padding:5px 12px;font-size:12px;cursor:pointer;color:var(--text-primary);';
      opt.onmouseenter = () => opt.style.background = 'var(--accent)';
      opt.onmouseleave = () => opt.style.background = 'none';
      opt.onclick = () => { menu.remove(); onSelect(item); };
      menu.appendChild(opt);
    });
    document.body.appendChild(menu);
    setTimeout(() => document.addEventListener('click', function rm() { menu.remove(); document.removeEventListener('click', rm); }), 0);
  }

  // Helpers
  let collaborators = {};

  function setCollaborators(collabs) { collaborators = collabs || {}; }

  function threadAuthor(c) { return c.thread?.[0]?.author || "unknown"; }
  function threadTime(c) { return c.thread?.[0]?.timestamp || c.thread?.[0]?.createdAt || ""; }

  // Returns the collaborator's color from the pushed map, or a stable hash-based
  // fallback if the author isn't in the map (ensures same author always gets same color).
  function authorColor(author) {
    if (collaborators[author]?.color) return collaborators[author].color;
    const colors = ["#4A90D9","#E57373","#81C784","#FFB74D","#BA68C8","#4DD0E1","#F06292","#AED581"];
    let h = 0;
    for (let i = 0; i < (author||"").length; i++) h = ((h << 5) - h + author.charCodeAt(i)) | 0;
    return colors[Math.abs(h) % colors.length];
  }

  // Formats an ISO 8601 timestamp as relative ("3h ago") for recent times,
  // or absolute ("11 May, 6:00 PM") for anything older than a week.
  function fmtTime(ts) {
    if (!ts) return "";
    const d = new Date(ts);
    const now = Date.now();
    const diff = now - d.getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return "now";
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    if (days < 7) return `${days}d ago`;
    // Absolute format for older timestamps
    const day = d.getDate();
    const mon = d.toLocaleString("en", { month: "short" });
    const time = d.toLocaleString("en", { hour: "numeric", minute: "2-digit", hour12: true });
    return `${day} ${mon}, ${time}`;
  }

  function esc(s) {
    if (typeof s !== "string") return "";
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  }

  return { init, setComments, setCollaborators, render };
})();
