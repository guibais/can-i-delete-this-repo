const seedRepos = () => [
  { id: "aurora-web", size: 4.29, clean: [["node_modules/", 3.02], [".next/", 0.41]], remote: true, changes: 3, unpushed: 2, stashes: 0, secrets: [[".env", false], [".env.local", false]], days: 1 },
  { id: "pixel-forge", size: 9.62, clean: [["Library/", 6.04], ["Temp/", 0.88]], remote: true, changes: 0, unpushed: 0, stashes: 0, secrets: [], days: 12 },
  { id: "ml-playground", size: 5.04, clean: [[".venv/", 3.01], ["__pycache__/", 0.01]], remote: true, changes: 0, unpushed: 0, stashes: 0, secrets: [[".env", true]], days: 60 },
  { id: "rust-raytracer", size: 2.94, clean: [["target/", 2.71]], remote: true, changes: 0, unpushed: 4, stashes: 0, secrets: [], days: 3 },
  { id: "orbit-ios", size: 2.61, clean: [["Pods/", 1.91]], remote: true, changes: 0, unpushed: 0, stashes: 0, secrets: [["GoogleService-Info.plist", true]], days: 30 },
  { id: "atlas-api", size: 1.82, clean: [["node_modules/", 1.37], ["dist/", 0.06]], remote: true, changes: 0, unpushed: 0, stashes: 0, secrets: [[".env", true], ["certs/server.pem", true]], days: 4 },
  { id: "landing-2024", size: 0.78, clean: [["node_modules/", 0.74]], remote: true, changes: 0, unpushed: 0, stashes: 0, secrets: [], days: 300 },
  { id: "design-tokens", size: 0.32, clean: [["node_modules/", 0.29]], remote: true, changes: 0, unpushed: 0, stashes: 1, secrets: [], days: 7 },
  { id: "side-quest", size: 0.21, clean: [["build/", 0.15]], remote: false, changes: 2, unpushed: 0, stashes: 0, secrets: [[".env", false]], days: 45 },
  { id: "notes-cli", size: 0.05, clean: [["target/", 0.04]], remote: false, changes: 0, unpushed: 0, stashes: 0, secrets: [], days: 90 },
  { id: "dotfiles", size: 0.006, clean: [], remote: true, changes: 0, unpushed: 0, stashes: 0, secrets: [], days: 2 }
].map((repo) => ({
  ...repo,
  clean: repo.clean.map(([path, size]) => ({ path, size })),
  secrets: repo.secrets.map(([path, synced]) => ({ path, synced }))
}));

const issueDefs = [
  { key: "noRemote", sev: 2, icon: "cloud-off", count: (r) => (r.remote ? 0 : 1) },
  { key: "changes", sev: 1, icon: "pencil", count: (r) => r.changes },
  { key: "unpushed", sev: 1, icon: "circle-arrow-up", count: (r) => r.unpushed },
  { key: "stashes", sev: 1, icon: "archive", count: (r) => r.stashes },
  { key: "secrets", sev: 1, icon: "key-round", count: (r) => r.secrets.filter((s) => !s.synced).length }
];

const severityStyles = {
  0: { color: "var(--green)", bg: "rgba(48,209,88,.14)", border: "rgba(48,209,88,.3)", icon: "badge-check", folder: "linear-gradient(180deg,#4cd964,#28a745)" },
  1: { color: "var(--amber)", bg: "rgba(255,159,10,.14)", border: "rgba(255,159,10,.3)", icon: "triangle-alert", folder: "linear-gradient(180deg,#ffb340,#ff8c00)" },
  2: { color: "var(--red)", bg: "rgba(255,69,58,.14)", border: "rgba(255,69,58,.3)", icon: "octagon-x", folder: "linear-gradient(180deg,#ff6961,#e0302a)" }
};

const cleanSize = (r) => r.clean.reduce((sum, item) => sum + item.size, 0);
const issuesOf = (r) => issueDefs.map((def) => ({ ...def, n: def.count(r) })).filter((issue) => issue.n > 0);
const severityOf = (r) => Math.max(0, ...issuesOf(r).map((issue) => issue.sev));

const filters = {
  all: { icon: "layers", color: "var(--blue)", test: () => true },
  safe: { icon: "badge-check", color: "var(--green)", test: (r) => severityOf(r) === 0 },
  attention: { icon: "triangle-alert", color: "var(--amber)", test: (r) => severityOf(r) === 1 },
  local: { icon: "hard-drive", color: "var(--red)", test: (r) => !r.remote },
  secrets: { icon: "key-round", color: "#ffd60a", test: (r) => r.secrets.length > 0 },
  cleanable: { icon: "sparkles", color: "var(--purple)", test: (r) => cleanSize(r) > 0 }
};

const fixes = {
  noRemote: (r) => { r.remote = true; return ["toast.published", { name: r.id }]; },
  changes: (r) => { r.changes = 0; r.unpushed = 0; return ["toast.committed", { name: r.id }]; },
  unpushed: (r) => { r.unpushed = 0; return ["toast.pushed", { name: r.id }]; },
  stashes: (r) => { r.stashes = 0; return ["toast.applied", { name: r.id }]; },
  secrets: (r) => {
    const n = r.secrets.filter((s) => !s.synced).length;
    r.secrets.forEach((s) => { s.synced = true; });
    return ["toast.backup", { n }];
  }
};

const state = {
  repos: seedRepos(),
  filter: "all",
  selected: new Set(),
  active: "aurora-web",
  query: "",
  busy: new Set(),
  scanned: 0,
  scanDone: false,
  modal: null,
  fetching: false
};

const t = (key, vars) => i18n.t(key, vars);
const locale = () => (i18n.lang === "pt" ? "pt-BR" : "en");
const icon = (name, style = "") => `<i data-lucide="${name}" style="${style}"></i>`;

const formatSize = (gb) => {
  if (gb <= 0) return "0 MB";
  const number = new Intl.NumberFormat(locale(), { maximumFractionDigits: gb >= 1 ? 2 : 0 });
  return gb >= 1 ? `${number.format(gb)} GB` : `${number.format(Math.max(1, gb * 1024))} MB`;
};

const relativeDays = (days) => {
  const formatter = new Intl.RelativeTimeFormat(locale(), { numeric: "auto" });
  if (days >= 365) return formatter.format(-Math.round(days / 365), "year");
  if (days >= 30) return formatter.format(-Math.round(days / 30), "month");
  return formatter.format(-days, "day");
};

const scannedRepos = () => state.repos.slice(0, state.scanned);
const visibleRepos = () => scannedRepos()
  .filter(filters[state.filter].test)
  .filter((r) => r.id.includes(state.query.toLowerCase()))
  .sort((a, b) => b.size - a.size);
const selectedRepos = () => state.repos.filter((r) => state.selected.has(r.id));
const repoById = (id) => state.repos.find((r) => r.id === id);

const badge = (sev) => {
  const style = severityStyles[sev];
  return `<span class="badge" style="color:${style.color};background:${style.bg}">${icon(style.icon)}${t(`sev.${sev}`)}</span>`;
};

const folder = (r) => `<span class="folder" style="background:${severityStyles[severityOf(r)].folder}">${icon("folder")}</span>`;

const renderTitlebar = () => `
  <div class="titlebar">
    <div class="lights"><i></i><i></i><i></i></div>
    <div class="tb-title"><b id="tb-title"></b><span id="tb-sub"></span></div>
    <div class="tb-tools">
      <button class="icon-btn" data-action="vault" title="Vault">${icon("shield")}</button>
      <button class="icon-btn" id="fetch" data-action="fetch" title="Fetch All">${icon("refresh-cw")}</button>
      <label class="search">${icon("search")}<input id="search" placeholder="${t("app.search")}" /></label>
    </div>
  </div>
  <div class="app">
    <aside class="sidebar" id="sidebar"></aside>
    <div class="list" id="list"></div>
    <div class="detail" id="detail"></div>
  </div>
  <div class="toast" id="toast">${icon("circle-check")}<span></span></div>
  <div id="modal"></div>
  <div class="scanning" id="scanning"></div>`;

const renderSidebar = () => {
  const repos = scannedRepos();
  const total = repos.reduce((sum, r) => sum + r.size, 0);
  const reclaimable = repos.reduce((sum, r) => sum + cleanSize(r), 0);
  const ratio = total ? (reclaimable / total) * 100 : 0;
  const items = Object.entries(filters).map(([key, f]) => `
    <button class="filter ${state.filter === key ? "active" : ""}" data-action="filter" data-id="${key}">
      ${icon(f.icon, `color:${f.color}`)}${t(`filter.${key}`)}<span class="count">${repos.filter(f.test).length}</span>
    </button>`).join("");
  return `<h6>${t("app.section")}</h6>${items}
    <div class="storage">
      <small>${t("app.storage")}</small>
      <strong>${formatSize(total)}</strong>
      <div class="bar"><div style="width:${ratio}%"></div></div>
      <p>${icon("sparkles")}${t("app.reclaimable", { v: formatSize(reclaimable) })}</p>
    </div>`;
};

const renderActionBar = (repos) => {
  const selected = repos.filter((r) => state.selected.has(r.id));
  const targets = selected.length ? selected : repos;
  const safe = targets.filter((r) => severityOf(r) === 0);
  const cleanable = targets.filter((r) => cleanSize(r) > 0);
  const allChecked = repos.length > 0 && selected.length === repos.length;
  const showClean = state.filter === "cleanable" || (selected.length && cleanable.length);
  const showTrash = state.filter === "safe" || (selected.length && safe.length);
  return `
    <div class="actionbar">
      <label><input type="checkbox" class="checkbox" data-action="select-all" ${allChecked ? "checked" : ""} />${selected.length ? t("app.selected", { n: selected.length }) : t("app.selectAll")}</label>
      <span class="spacer"></span>
      ${selected.length ? `<button class="chip-btn" data-action="bulk-push">${icon("circle-arrow-up")}${t("act.push")}</button>
      <button class="chip-btn blue" data-action="bulk-backup">${icon("lock")}${t("act.backup")}</button>` : ""}
      ${showClean ? `<button class="chip-btn purple" data-action="bulk-clean" ${cleanable.length ? "" : "disabled"}>${icon("sparkles")}${selected.length ? t("act.clean") : t("app.cleanAll")}</button>` : ""}
      ${showTrash ? `<button class="chip-btn red" data-action="bulk-trash" ${safe.length ? "" : "disabled"}>${icon("trash-2")}${selected.length ? t("act.trash") : t("app.removeAll")}</button>` : ""}
    </div>`;
};

const renderRow = (r) => {
  const busy = state.busy.has(r.id);
  const reclaim = cleanSize(r);
  return `
    <div class="row ${state.active === r.id ? "selected" : ""}" data-action="open" data-id="${r.id}" id="row-${r.id}">
      <input type="checkbox" class="checkbox" data-action="check" data-id="${r.id}" ${state.selected.has(r.id) ? "checked" : ""} />
      <div class="name-cell">${folder(r)}<div><b>${r.id}</b><span class="path">~/Developer/${r.id}</span></div>${busy ? '<span class="spinner"></span>' : ""}</div>
      ${badge(severityOf(r))}
      <span class="num">${formatSize(r.size)}</span>
      <span class="num ${reclaim ? "purple" : ""}">${reclaim ? formatSize(reclaim) : "—"}</span>
    </div>`;
};

const renderList = () => {
  const repos = visibleRepos();
  const rows = repos.length ? repos.map(renderRow).join("") : `<div class="empty" style="padding:40px;text-align:center">${t("empty")}</div>`;
  return `${renderActionBar(repos)}
    <div class="thead"><span></span><span>${t("col.name")}</span><span>${t("col.status")}</span><span>${t("col.size")}</span><span>${t("col.clean")}</span></div>
    <div class="rows">${rows}</div>`;
};

const renderIssues = (r) => {
  const issues = issuesOf(r);
  if (!issues.length) return "";
  const items = issues.map((issue) => `
    <div class="item">
      ${icon(issue.icon, `color:${severityStyles[issue.sev].color};font-size:15px`)}
      <span class="grow">${t(`issue.${issue.key}`, { n: issue.n })}</span>
      <button class="chip-btn ${issue.sev === 2 ? "red" : "green"}" data-action="fix" data-id="${r.id}" data-fix="${issue.key}">${t(`fix.${issue.key}`)}</button>
    </div>`).join("");
  return `<div class="card"><div class="card-head">${icon("message-square-warning")}${t("card.issues")}</div>${items}</div>`;
};

const renderSecrets = (r) => {
  const pending = r.secrets.some((s) => !s.synced);
  const items = r.secrets.map((s) => `
    <div class="item">
      ${icon("file-key", "color:#ffd60a")}
      <span class="grow mono">${s.path}</span>
      <span class="state" style="color:${s.synced ? "var(--green)" : "var(--amber)"}">${icon(s.synced ? "cloud-check" : "cloud-alert")}${t(s.synced ? "secret.synced" : "secret.pending")}</span>
    </div>`).join("") || `<span class="empty">${t("none.secrets")}</span>`;
  const action = pending ? `<button class="chip-btn blue" data-action="fix" data-fix="secrets" data-id="${r.id}">${icon("lock")}${t("act.backup")}</button>` : "";
  return `<div class="card"><div class="card-head">${icon("key-round")}${t("card.secrets")}${action}</div>${items}</div>`;
};

const renderCleanables = (r) => {
  const max = r.clean[0]?.size ?? 1;
  const items = r.clean.map((c) => `
    <div class="item"><div class="grow">
      <div style="display:flex;justify-content:space-between"><span class="mono">${c.path}</span><span class="num">${formatSize(c.size)}</span></div>
      <div class="mini-bar"><div style="width:${(c.size / max) * 100}%"></div></div>
    </div></div>`).join("") || `<span class="empty">${t("none.clean")}</span>`;
  const action = r.clean.length ? `<button class="chip-btn purple" data-action="clean-one" data-id="${r.id}">${icon("sparkles")}${t("act.clean")}</button>` : "";
  return `<div class="card"><div class="card-head">${icon("package")}${t("card.clean")}${action}</div>${items}</div>`;
};

const renderDetail = () => {
  const r = repoById(state.active);
  if (!r || !scannedRepos().includes(r)) {
    return `<div class="empty" style="margin:auto;text-align:center">${icon("panel-right", "font-size:34px;opacity:.4")}<p>${t("detail.empty")}</p></div>`;
  }
  const sev = severityOf(r);
  const style = severityStyles[sev];
  return `
    <div class="d-head"><span class="folder" style="background:${style.folder}">${icon("folder")}</span><div><b>${r.id}</b><span class="path">~/Developer/${r.id}</span></div></div>
    <div class="open-row">
      <span class="chip-btn">${icon("folder-open")}${t("act.finder")}</span>
      <span class="chip-btn">${icon("terminal")}${t("act.terminal")}</span>
      <span class="chip-btn">${icon("code")}${t("act.editor")}</span>
    </div>
    <div class="banner" style="background:${style.bg};border-color:${style.border}">
      ${icon(style.icon, `color:${style.color}`)}
      <div><b>${t(`banner.${sev}.t`)}</b><p>${t(`banner.${sev}.d`)}</p></div>
    </div>
    <div class="stats">
      <div class="stat">${icon("hard-drive", "color:var(--blue)")}<strong>${formatSize(r.size)}</strong><span>${t("stat.size")}</span></div>
      <div class="stat">${icon("sparkles", "color:var(--purple)")}<strong>${formatSize(cleanSize(r))}</strong><span>${t("stat.clean")}</span></div>
      <div class="stat">${icon("git-branch", "color:var(--teal)")}<strong>main</strong><span>${t("stat.branch")}</span></div>
      <div class="stat">${icon("clock", "color:#5e5ce6")}<strong>${relativeDays(r.days)}</strong><span>${t("stat.last")}</span></div>
    </div>
    ${renderIssues(r)}
    ${renderSecrets(r)}
    ${renderCleanables(r)}
    <div class="card"><div class="card-head">${icon("trash-2")}${t("card.danger")}<button class="chip-btn red" data-action="trash-one" data-id="${r.id}">${t("act.trash")}</button></div><span class="empty">${t("card.dangerText")}</span></div>`;
};

const renderModal = () => {
  const modal = state.modal;
  if (!modal) return "";
  return `<div class="modal-backdrop" data-action="modal-cancel"><div class="modal">
    ${icon("triangle-alert", "").replace("<i", '<i class="big"')}
    <b>${modal.title}</b><p>${modal.text}</p>
    <div class="modal-actions">
      <button class="danger" data-action="modal-confirm">${modal.confirm}</button>
      <button data-action="modal-cancel">${t("act.cancel")}</button>
    </div></div></div>`;
};

const renderScanning = () => {
  const total = state.repos.length;
  const current = state.repos[Math.min(state.scanned, total - 1)]?.id ?? "";
  return `<div class="scan-box">${icon("radar")}<b>${t("scan.title")}</b><p>~/Developer/${current}</p>
    <div class="bar"><div style="width:${(state.scanned / total) * 100}%"></div></div>
    <p style="margin-top:10px">${t("scan.found", { n: state.scanned })}</p></div>`;
};

const app = document.getElementById("app");
const region = (id) => app.querySelector(`#${id}`);

const render = () => {
  region("tb-title").textContent = t(`filter.${state.filter}`);
  region("tb-sub").textContent = t("app.repos", { n: visibleRepos().length });
  region("sidebar").innerHTML = renderSidebar();
  region("list").innerHTML = renderList();
  region("detail").innerHTML = renderDetail();
  region("modal").innerHTML = renderModal();
  region("scanning").innerHTML = renderScanning();
  region("scanning").classList.toggle("done", state.scanDone);
  lucide.createIcons();
};

const mount = () => {
  app.innerHTML = renderTitlebar();
  region("search").value = state.query;
  region("search").addEventListener("input", (event) => {
    state.query = event.target.value;
    render();
  });
  render();
};

let toastTimer;
const toast = (key, vars) => {
  const node = region("toast");
  node.querySelector("span").textContent = t(key, vars);
  node.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => node.classList.remove("show"), 2600);
};

const work = (repos, operation) => {
  repos.forEach((r) => state.busy.add(r.id));
  render();
  setTimeout(() => {
    const result = operation();
    repos.forEach((r) => state.busy.delete(r.id));
    render();
    if (result) toast(...result);
  }, 650);
};

const confirmThen = (modal) => {
  state.modal = modal;
  render();
};

const cleanRepos = (repos) => {
  const freed = repos.reduce((sum, r) => sum + cleanSize(r), 0);
  work(repos, () => {
    repos.forEach((r) => { r.size = Math.max(0.004, r.size - cleanSize(r)); r.clean = []; });
    return ["toast.cleaned", { v: formatSize(freed) }];
  });
};

const trashRepos = (repos) => {
  repos.forEach((r) => region(`row-${r.id}`)?.classList.add("leaving"));
  setTimeout(() => {
    const ids = new Set(repos.map((r) => r.id));
    state.repos = state.repos.filter((r) => !ids.has(r.id));
    state.scanned = state.repos.length;
    ids.forEach((id) => state.selected.delete(id));
    if (ids.has(state.active)) state.active = visibleRepos()[0]?.id ?? null;
    render();
    toast("toast.trashed", { n: ids.size });
  }, 350);
};

const bulkTargets = () => {
  const selected = selectedRepos();
  return selected.length ? selected : visibleRepos();
};

const actions = {
  filter: ({ id }) => { state.filter = id; state.selected.clear(); render(); },
  open: ({ id }) => { state.active = id; render(); },
  check: ({ id }) => { state.selected.has(id) ? state.selected.delete(id) : state.selected.add(id); render(); },
  "select-all": () => {
    const repos = visibleRepos();
    const all = repos.every((r) => state.selected.has(r.id));
    repos.forEach((r) => (all ? state.selected.delete(r.id) : state.selected.add(r.id)));
    render();
  },
  fix: ({ id, fix }) => {
    const r = repoById(id);
    work([r], () => fixes[fix](r));
  },
  "bulk-push": () => {
    const repos = selectedRepos().filter((r) => r.remote);
    work(repos, () => { repos.forEach((r) => { r.unpushed = 0; }); return ["toast.pushed", { name: repos.map((r) => r.id).join(", ") }]; });
  },
  "bulk-backup": () => {
    const repos = selectedRepos();
    const n = repos.reduce((sum, r) => sum + r.secrets.filter((s) => !s.synced).length, 0);
    work(repos, () => { repos.forEach((r) => r.secrets.forEach((s) => { s.synced = true; })); return ["toast.backup", { n }]; });
  },
  "bulk-clean": () => {
    const repos = bulkTargets().filter((r) => cleanSize(r) > 0);
    const freed = repos.reduce((sum, r) => sum + cleanSize(r), 0);
    confirmThen({ title: t("confirm.clean", { n: repos.length }), text: t("confirm.cleanText", { v: formatSize(freed) }), confirm: t("act.clean"), run: () => cleanRepos(repos) });
  },
  "bulk-trash": () => {
    const repos = bulkTargets().filter((r) => severityOf(r) === 0);
    confirmThen({ title: t("confirm.trash", { n: repos.length }), text: t("confirm.trashText"), confirm: t("act.trash"), run: () => trashRepos(repos) });
  },
  "clean-one": ({ id }) => {
    const r = repoById(id);
    confirmThen({ title: t("confirm.clean", { n: 1 }), text: t("confirm.cleanText", { v: formatSize(cleanSize(r)) }), confirm: t("act.clean"), run: () => cleanRepos([r]) });
  },
  "trash-one": ({ id }) => {
    const r = repoById(id);
    const text = severityOf(r) === 0 ? t("confirm.trashText") : t("confirm.trashUnsafe");
    confirmThen({ title: t("confirm.trash", { n: 1 }), text, confirm: t("act.trash"), run: () => trashRepos([r]) });
  },
  "modal-confirm": () => { const run = state.modal.run; state.modal = null; render(); run(); },
  "modal-cancel": () => { state.modal = null; render(); },
  fetch: () => {
    region("fetch").classList.add("spin");
    setTimeout(() => { region("fetch").classList.remove("spin"); toast("toast.fetched"); }, 1100);
  },
  vault: () => document.getElementById("vault").scrollIntoView({ behavior: "smooth" })
};

app.addEventListener("click", (event) => {
  const target = event.target.closest("[data-action]");
  if (!target) return;
  if (target.classList.contains("modal-backdrop") && event.target !== target) return;
  event.stopPropagation();
  actions[target.dataset.action]?.(target.dataset);
});

const scan = () => {
  const step = () => {
    state.scanned += 1;
    render();
    if (state.scanned < state.repos.length) {
      setTimeout(step, 140);
      return;
    }
    setTimeout(() => { state.scanDone = true; render(); }, 400);
  };
  setTimeout(step, 300);
};

const resetDemo = () => {
  Object.assign(state, { repos: seedRepos(), filter: "all", selected: new Set(), active: "aurora-web", query: "", busy: new Set(), scanned: 0, scanDone: false, modal: null });
  mount();
  scan();
};

const startWhenVisible = () => {
  const observer = new IntersectionObserver((entries) => {
    if (!entries.some((entry) => entry.isIntersecting)) return;
    observer.disconnect();
    scan();
  }, { threshold: 0.25 });
  observer.observe(app);
};

document.getElementById("reset").addEventListener("click", resetDemo);
document.addEventListener("langchange", mount);
