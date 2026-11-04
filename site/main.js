const encryptRows = [
  [".env", "DATABASE_URL=postgres://app"],
  [".env.local", "STRIPE_SECRET=sk_live_51H"],
  ["certs/server.pem", "-----BEGIN PRIVATE KEY"],
  ["GoogleService-Info.plist", "API_KEY=AIzaSyD4x"]
];

const cipherAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const randomCipher = (length) => "GMV1·" + Array.from({ length }, () => cipherAlphabet[Math.floor(Math.random() * cipherAlphabet.length)]).join("");

const renderEncrypt = () => {
  const panel = document.getElementById("encrypt");
  const rows = encryptRows.map(([file, content], index) => `
    <div class="encrypt-row">
      <span class="plain" title="${file}">${content}…</span>
      <i data-lucide="lock"></i>
      <span class="cipher" data-cipher="${index}">${randomCipher(22)}</span>
    </div>`).join("");
  const tree = `secrets-vault/
├── .vault.json
├── index.json
└── github.com/octodev/aurora-web/
    ├── manifest.json
    └── files/
        ├── <em>.env.enc</em>
        └── <em>.env.local.enc</em>`;
  panel.innerHTML = rows + `<div class="tree">${tree}</div>`;
  lucide.createIcons();
};

const animateCipher = () => {
  setInterval(() => {
    document.querySelectorAll("[data-cipher]").forEach((node) => { node.textContent = randomCipher(22); });
  }, 120);
};

const revealOnScroll = () => {
  const observer = new IntersectionObserver((entries) => {
    entries.filter((entry) => entry.isIntersecting).forEach((entry) => {
      entry.target.classList.add("visible");
      observer.unobserve(entry.target);
    });
  }, { threshold: 0.12 });
  document.querySelectorAll(".reveal").forEach((node) => observer.observe(node));
};

const bindCopyButtons = () => {
  document.querySelectorAll("[data-copy]").forEach((button) => {
    button.addEventListener("click", () => {
      navigator.clipboard?.writeText(button.dataset.copy);
      button.innerHTML = '<i data-lucide="check"></i>';
      lucide.createIcons();
    });
  });
};

const bindLanguage = () => {
  document.querySelectorAll("[data-lang]").forEach((button) => {
    button.addEventListener("click", () => i18n.set(button.dataset.lang));
  });
};

i18n.init();
mount();
startWhenVisible();
renderEncrypt();
animateCipher();
revealOnScroll();
bindCopyButtons();
bindLanguage();
lucide.createIcons();
