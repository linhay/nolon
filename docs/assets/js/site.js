const dict = {
  zh: {
    "nav.console": "主控制台",
    "nav.resource": "资源中心",
    "nav.providers": "Provider",
    "nav.codex": "Codex 深度支持",
    "nav.plugins": "插件管理",
    "nav.arch": "架构",
    "nav.ecosystem": "生态模板",
    "nav.download": "下载",
    "nav.faq": "FAQ",
    "hero.kicker": "AI 编程工具主控制台",
    "hero.title": "一套资源，编排到多 Provider 的开发工作流",
    "hero.lead": "Nolon 在 macOS 上提供统一的主控制台：资源编排、远程安装与 Codex 深度支持并行工作。",
    "hero.badge1": "统一资源编排",
    "hero.badge2": "远程安装闭环",
    "hero.badge3": "Codex 深度支持",
    "hero.ctaDownload": "下载最新版本",
    "hero.ctaRepo": "查看仓库",
    "console.title": "主控制台：默认三栏主页",
    "console.desc": "左侧 Provider、中央内容标签、右侧详情网格，形成稳定的日常操作路径。",
    "console.caption": "当前实机截图：主界面默认三栏状态。",
    "resource.title": "资源中心：远程发现与安装",
    "resource.desc": "通过叠层资源中心统一浏览并安装 Skills、Workflows、MCP，减少跨 Provider 的重复操作。",
    "resource.skills": "统一管理技能资产并投射到目标 Provider。",
    "resource.workflows": "安装工作流并保持本地与远程一致。",
    "resource.mcp": "安装与配置 MCP 资源，减少手工配置错误。",
    "providers.title": "Provider 能力矩阵（7+）",
    "providers.desc": "内置模板覆盖 7+ Provider，基础能力与 Vendor 扩展能力按标签动态呈现。",
    "providers.baseTitle": "基础标签",
    "providers.base": "Skills / Workflows / MCP 为通用底座。",
    "providers.vendorTitle": "Vendor 扩展",
    "providers.vendor": "可按 Provider 能力扩展 Accounts、Usage、Binary、Advanced 等视图。",
    "codex.title": "Codex 深度支持",
    "codex.desc": "从账号与用量到二进制与高级配置，Nolon 将 Codex 相关能力集中在可视化控制面。",
    "codex.item1Title": "账号与用量",
    "codex.item1": "查看账号状态、用量趋势与关键指标。",
    "codex.item2Title": "Binary 管理",
    "codex.item2": "查看可用版本并切换使用二进制。",
    "codex.item3Title": "Advanced 配置",
    "codex.item3": "聚合常见高级配置项，降低配置门槛。",
    "codex.item4Title": "运行与诊断",
    "codex.item4": "结合 CLI/SDK 能力，支持更清晰的运行态排查。",
    "plugins.title": "插件管理（独立页面）",
    "plugins.desc": "插件管理位于 Tools 分组，为独立页面，不属于 MCP 页面。首期内置 XcodeMCPKit，并支持版本升级检测。",
    "plugins.xcode": "检查 GitHub 稳定版更新（忽略 pre-release），命中后显示 Upgrade 按钮。",
    "plugins.futureTitle": "可扩展插件位",
    "plugins.future": "插件列表可继续扩展，不干扰现有 Provider/MCP 结构。",
    "arch.title": "开发流程：SDK → CLI → App",
    "arch.desc": "核心能力优先下沉到 SDK，再由 CLI 和 App 复用，App 侧聚焦编排与展示。",
    "arch.note": "同时配合迁移助手、链接修复、漂移治理机制，保障长期可维护性。",
    "eco.title": "生态项目：Leaderboard Template",
    "eco.desc": "`projects/leaderboard-template` 提供可 fork 的独立榜单模板，包含提交契约、快照构建与 Pages 发布链路。",
    "eco.ctaSite": "查看模板站点",
    "eco.ctaRepo": "查看模板源码",
    "download.title": "下载与更新",
    "download.desc": "支持 GitHub Releases 手动下载，也支持 Sparkle appcast 自动更新链路。",
    "download.releaseTitle": "GitHub Releases",
    "download.releaseDesc": "最新稳定版本下载入口。",
    "download.appcastDesc": "应用内更新源。",
    "faq.q1": "为什么写 7+ 而不是更大的数字？",
    "faq.a1": "官网与当前仓库内置模板口径保持一致，避免宣传与实现脱节。",
    "faq.q2": "插件管理和 MCP 是同一个页面吗？",
    "faq.a2": "不是。插件管理是左侧 Tools 下的独立页面。",
    "faq.q3": "leaderboard-template 属于主应用功能吗？",
    "faq.a3": "它是生态模板项目，面向可 fork 的独立站点能力。"
  },
  en: {
    "nav.console": "Main Console",
    "nav.resource": "Resource Center",
    "nav.providers": "Providers",
    "nav.codex": "Codex Deep Support",
    "nav.plugins": "Plugin Management",
    "nav.arch": "Architecture",
    "nav.ecosystem": "Ecosystem",
    "nav.download": "Download",
    "nav.faq": "FAQ",
    "hero.kicker": "Main Console for AI Coding Tools",
    "hero.title": "One resource space, orchestrated across multiple providers",
    "hero.lead": "Nolon provides a unified macOS console for orchestration, remote installs, and deep Codex workflows.",
    "hero.badge1": "Unified Orchestration",
    "hero.badge2": "Remote Install Loop",
    "hero.badge3": "Deep Codex Support",
    "hero.ctaDownload": "Download Latest",
    "hero.ctaRepo": "View Repository",
    "console.title": "Main Console: Default 3-column workspace",
    "console.desc": "Provider sidebar, tab navigation, and detail grid create a stable daily path.",
    "console.caption": "Real screenshot from the default 3-column main view.",
    "resource.title": "Resource Center: Discover and install remotely",
    "resource.desc": "Install Skills, Workflows, and MCP resources from a unified overlay flow.",
    "resource.skills": "Manage skills once and project them to target providers.",
    "resource.workflows": "Install workflow assets and keep local state aligned.",
    "resource.mcp": "Install and configure MCP resources with fewer manual errors.",
    "providers.title": "Provider Capability Matrix (7+)",
    "providers.desc": "Built-in templates cover 7+ providers, with dynamic tabs for base and vendor capabilities.",
    "providers.baseTitle": "Base Tabs",
    "providers.base": "Skills / Workflows / MCP form the common baseline.",
    "providers.vendorTitle": "Vendor Extensions",
    "providers.vendor": "Accounts, Usage, Binary, Advanced and more are exposed per provider capability.",
    "codex.title": "Codex Deep Support",
    "codex.desc": "From account and usage to binary and advanced settings, Codex workflows are surfaced in one place.",
    "codex.item1Title": "Account & Usage",
    "codex.item1": "Track account state, usage trends, and key metrics.",
    "codex.item2Title": "Binary Management",
    "codex.item2": "Inspect available versions and switch runtime binary.",
    "codex.item3Title": "Advanced Settings",
    "codex.item3": "Collect common advanced settings in one manageable panel.",
    "codex.item4Title": "Runtime & Diagnostics",
    "codex.item4": "Leverage CLI/SDK-level capabilities for clearer runtime troubleshooting.",
    "plugins.title": "Plugin Management (Independent Page)",
    "plugins.desc": "Plugin Management lives under Tools as a standalone page, not under MCP. It ships with XcodeMCPKit and upgrade checks.",
    "plugins.xcode": "Checks stable GitHub releases (ignoring pre-release) and shows Upgrade when a newer version exists.",
    "plugins.futureTitle": "Extensible Slot",
    "plugins.future": "Plugin entries can expand without changing Provider/MCP structure.",
    "arch.title": "Development Flow: SDK → CLI → App",
    "arch.desc": "Core capability lands in SDK first, then reused by CLI and app. The app focuses on orchestration and presentation.",
    "arch.note": "Migration, repair, and drift-governance complete the long-term maintenance loop.",
    "eco.title": "Ecosystem: Leaderboard Template",
    "eco.desc": "`projects/leaderboard-template` is a forkable standalone leaderboard stack with submission contracts, snapshots, and Pages pipelines.",
    "eco.ctaSite": "Open Template Site",
    "eco.ctaRepo": "Open Template Source",
    "download.title": "Download and Updates",
    "download.desc": "Use GitHub Releases for manual downloads, or Sparkle appcast for in-app updates.",
    "download.releaseTitle": "GitHub Releases",
    "download.releaseDesc": "Entry for the latest stable release.",
    "download.appcastDesc": "In-app update feed.",
    "faq.q1": "Why does the site say 7+ providers?",
    "faq.a1": "The website intentionally matches current in-repo built-in template coverage.",
    "faq.q2": "Is Plugin Management the same as MCP page?",
    "faq.a2": "No. Plugin Management is a standalone page under Tools.",
    "faq.q3": "Is leaderboard-template part of the main app feature set?",
    "faq.a3": "No. It is an ecosystem template for forkable standalone sites."
  }
};

function setLanguage(lang) {
  const fallback = "zh";
  const selected = dict[lang] ? lang : fallback;
  const table = dict[selected];
  document.documentElement.lang = selected === "zh" ? "zh-CN" : "en";
  localStorage.setItem("lang", selected);

  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const key = el.getAttribute("data-i18n");
    if (table[key]) {
      el.textContent = table[key];
    }
  });

  document.querySelectorAll(".lang-switch button").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.lang === selected);
  });
}

function bindLanguageSwitch() {
  document.querySelectorAll(".lang-switch button").forEach((btn) => {
    btn.addEventListener("click", () => setLanguage(btn.dataset.lang));
  });
}

function bindNavActive() {
  const links = Array.from(document.querySelectorAll(".nav a"));
  const sectionIds = links.map((link) => link.getAttribute("href")).filter(Boolean);

  const io = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      const id = `#${entry.target.id}`;
      if (!entry.isIntersecting) return;
      links.forEach((link) => {
        link.classList.toggle("active", link.getAttribute("href") === id);
      });
    });
  }, { rootMargin: "-35% 0px -55% 0px", threshold: 0.01 });

  sectionIds.forEach((id) => {
    const sec = document.querySelector(id);
    if (sec) io.observe(sec);
  });
}

function initYear() {
  const el = document.getElementById("year");
  if (el) el.textContent = new Date().getFullYear();
}

(function init() {
  initYear();
  bindLanguageSwitch();
  bindNavActive();
  setLanguage(localStorage.getItem("lang") || "zh");
})();
