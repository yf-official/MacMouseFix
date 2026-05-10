const STORAGE_KEY = "mac-mouse-fix-pro-state-v1";

const actions = [
  "Primary Click",
  "Secondary Click",
  "Middle Click",
  "Back",
  "Forward",
  "Mission Control",
  "App Expose",
  "Show Desktop",
  "Launchpad",
  "Smart Zoom",
  "Quick Look",
  "Move Space Left",
  "Move Space Right",
  "Keyboard Shortcut",
  "Open Application",
  "Zoom",
  "Horizontal Scroll",
  "None",
];

const controls = [
  { id: "left", name: "Left Click", meta: "Primary button", glyph: "L" },
  { id: "right", name: "Right Click", meta: "Secondary button", glyph: "R" },
  { id: "middle", name: "Wheel Click", meta: "Middle button", glyph: "M" },
  { id: "button4", name: "Button 4", meta: "Thumb back", glyph: "4" },
  { id: "button5", name: "Button 5", meta: "Thumb forward", glyph: "5" },
];

const directions = [
  { id: "up", label: "Drag Up", glyph: "↑" },
  { id: "down", label: "Drag Down", glyph: "↓" },
  { id: "left", label: "Drag Left", glyph: "←" },
  { id: "right", label: "Drag Right", glyph: "→" },
];

const defaultState = {
  enabled: true,
  theme: "light",
  device: "MX Master 3S",
  activeProfileId: "global",
  editorProfileId: "global",
  selectedGestureButton: "button4",
  selectedGestureEditor: "button4",
  currentSpace: 1,
  permissions: {
    accessibility: true,
    inputMonitoring: true,
    helper: false,
  },
  scrolling: {
    natural: false,
    smooth: true,
    momentum: true,
    horizontal: true,
    smoothness: 72,
    speed: 62,
    acceleration: 35,
    precision: 6,
  },
  gestures: {
    threshold: 48,
    holdButton: true,
    overlay: true,
  },
  menubar: {
    launchAtLogin: true,
    menuIcon: true,
    notifications: true,
    autoUpdates: true,
  },
  license: {
    activated: false,
    key: "",
    trialDays: 14,
  },
  profiles: [
    {
      id: "global",
      name: "Global",
      bundle: "*",
      fallback: true,
      mappings: {
        left: { action: "Primary Click", value: "" },
        right: { action: "Secondary Click", value: "" },
        middle: { action: "Mission Control", value: "" },
        button4: { action: "Back", value: "" },
        button5: { action: "Forward", value: "" },
      },
      gestures: {
        button4: {
          up: { action: "Mission Control", value: "" },
          down: { action: "Show Desktop", value: "" },
          left: { action: "Move Space Left", value: "" },
          right: { action: "Move Space Right", value: "" },
        },
        button5: {
          up: { action: "Smart Zoom", value: "" },
          down: { action: "Quick Look", value: "" },
          left: { action: "Back", value: "" },
          right: { action: "Forward", value: "" },
        },
      },
    },
    {
      id: "browser",
      name: "Browser",
      bundle: "com.apple.Safari",
      fallback: false,
      mappings: {
        left: { action: "Primary Click", value: "" },
        right: { action: "Secondary Click", value: "" },
        middle: { action: "Open Application", value: "Safari" },
        button4: { action: "Back", value: "" },
        button5: { action: "Forward", value: "" },
      },
      gestures: {
        button4: {
          up: { action: "Mission Control", value: "" },
          down: { action: "Show Desktop", value: "" },
          left: { action: "Back", value: "" },
          right: { action: "Forward", value: "" },
        },
        button5: {
          up: { action: "Zoom", value: "" },
          down: { action: "Smart Zoom", value: "" },
          left: { action: "Move Space Left", value: "" },
          right: { action: "Move Space Right", value: "" },
        },
      },
    },
  ],
  log: [
    { time: "20:32", title: "Loaded settings", detail: "Global profile" },
    { time: "20:32", title: "Helper waiting", detail: "Permission simulation" },
  ],
};

let state = loadState();
let dragStart = null;
let recordingTarget = null;

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return clone(defaultState);
    return normalizeState(JSON.parse(raw));
  } catch {
    return clone(defaultState);
  }
}

function normalizeState(candidate) {
  const merged = clone(defaultState);
  deepMerge(merged, candidate);
  if (!merged.profiles.some((profile) => profile.id === merged.activeProfileId)) {
    merged.activeProfileId = "global";
  }
  if (!merged.profiles.some((profile) => profile.id === merged.editorProfileId)) {
    merged.editorProfileId = merged.activeProfileId;
  }
  return merged;
}

function deepMerge(target, source) {
  Object.entries(source || {}).forEach(([key, value]) => {
    if (Array.isArray(value)) {
      target[key] = value;
      return;
    }
    if (value && typeof value === "object") {
      if (!target[key] || typeof target[key] !== "object") target[key] = {};
      deepMerge(target[key], value);
      return;
    }
    target[key] = value;
  });
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function activeProfile() {
  return state.profiles.find((profile) => profile.id === state.activeProfileId) || state.profiles[0];
}

function editorProfile() {
  return state.profiles.find((profile) => profile.id === state.editorProfileId) || activeProfile();
}

function nowLabel() {
  return new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function logEvent(title, detail = "") {
  state.log.unshift({ time: nowLabel(), title, detail });
  state.log = state.log.slice(0, 18);
  saveState();
  renderLog();
}

function showToast(title, detail = "") {
  const host = $("#toastHost");
  const toast = document.createElement("div");
  toast.className = "toast";
  toast.innerHTML = `<strong>${escapeHtml(title)}</strong><span>${escapeHtml(detail)}</span>`;
  host.append(toast);
  window.setTimeout(() => toast.remove(), 2800);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function render() {
  document.documentElement.dataset.theme = state.theme;
  $("#appShell").dataset.theme = state.theme;
  $("#deviceTitle").textContent = state.device;
  $("#activeProfileLabel").textContent = `${activeProfile().name} profile`;
  $("#spaceMetric").textContent = String(state.currentSpace);
  $("#scrollMetric").textContent = `${state.scrolling.smoothness}%`;

  renderSections();
  renderPower();
  renderProfiles();
  renderButtonTable();
  renderGestureEditor();
  renderPermissions();
  renderScrolling();
  renderMenubar();
  renderLicense();
  renderLog();
  renderScreen();
}

function renderSections() {
  $$(".segment[data-enabled]").forEach((button) => {
    button.classList.toggle("active", String(state.enabled) === button.dataset.enabled);
  });
  $$("#gestureButtonGroup .small-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.gestureButton === state.selectedGestureButton);
  });
  $$("[data-gesture-editor]").forEach((button) => {
    button.classList.toggle("active", button.dataset.gestureEditor === state.selectedGestureEditor);
  });
}

function renderPower() {
  $$(".status-pill").forEach((button) => {
    const key = button.dataset.togglePermission;
    button.disabled = !key;
  });
}

function renderProfiles() {
  const profileSelect = $("#profileSelect");
  profileSelect.innerHTML = state.profiles
    .map(
      (profile) =>
        `<option value="${profile.id}" ${profile.id === state.activeProfileId ? "selected" : ""}>${escapeHtml(
          profile.name,
        )}</option>`,
    )
    .join("");

  $("#deviceSelect").value = state.device;
  const profileList = $("#profileList");
  profileList.innerHTML = state.profiles
    .map(
      (profile) => `
        <button class="profile-card ${profile.id === state.editorProfileId ? "active" : ""}" data-edit-profile="${
          profile.id
        }">
          <span>
            <strong>${escapeHtml(profile.name)}</strong>
            <span>${escapeHtml(profile.bundle)}</span>
          </span>
          <span class="profile-badge">${profile.fallback ? "Base" : "App"}</span>
        </button>
      `,
    )
    .join("");

  const current = editorProfile();
  $("#profileEditorTitle").textContent = current.name;
  $("#profileNameInput").value = current.name;
  $("#profileBundleInput").value = current.bundle;
  $("#fallbackProfileToggle").checked = current.fallback;
  $("#deleteProfileButton").disabled = current.id === "global";
}

function renderButtonTable() {
  const profile = activeProfile();
  $("#buttonTable").innerHTML = controls
    .map((control) => {
      const mapping = profile.mappings[control.id] || { action: "None", value: "" };
      const requiresValue = needsValue(mapping.action);
      return `
        <div class="control-row" data-control-row="${control.id}">
          <div class="control-cell">
            <span class="control-glyph">${control.glyph}</span>
            <span class="control-meta">
              <strong>${control.name}</strong>
              <span>${control.meta}</span>
            </span>
          </div>
          <select data-action-select="${control.id}">
            ${actionOptions(mapping.action)}
          </select>
          <input
            class="shortcut-input"
            data-value-input="${control.id}"
            value="${escapeHtml(mapping.value)}"
            placeholder="${valuePlaceholder(mapping.action)}"
            ${requiresValue ? "" : "hidden"}
          />
          <button class="small-button" data-test-control="${control.id}">Run</button>
        </div>
      `;
    })
    .join("");
}

function actionOptions(selected) {
  return actions
    .map((action) => `<option value="${action}" ${action === selected ? "selected" : ""}>${action}</option>`)
    .join("");
}

function needsValue(action) {
  return action === "Keyboard Shortcut" || action === "Open Application";
}

function valuePlaceholder(action) {
  if (action === "Keyboard Shortcut") return "Click then press keys";
  if (action === "Open Application") return "App name or bundle id";
  return "";
}

function renderGestureEditor() {
  const profile = activeProfile();
  const buttonId = state.selectedGestureEditor;
  const buttonGestures = profile.gestures[buttonId] || {};
  $("#gestureEditor").innerHTML = directions
    .map((direction) => {
      const mapping = buttonGestures[direction.id] || { action: "None", value: "" };
      const requiresValue = needsValue(mapping.action);
      return `
        <div class="gesture-card" data-gesture-card="${direction.id}">
          <div class="gesture-card-header">
            <span class="direction-icon">${direction.glyph}</span>
            <strong>${direction.label}</strong>
          </div>
          <select data-gesture-select="${direction.id}">
            ${actionOptions(mapping.action)}
          </select>
          <input
            data-gesture-value="${direction.id}"
            value="${escapeHtml(mapping.value)}"
            placeholder="${valuePlaceholder(mapping.action)}"
            ${requiresValue ? "" : "hidden"}
          />
          <button class="small-button" data-test-gesture="${direction.id}">Run</button>
        </div>
      `;
    })
    .join("");

  $("#gestureThreshold").value = state.gestures.threshold;
  $("#thresholdOutput").textContent = `${state.gestures.threshold} px`;
  $("#holdGestureToggle").checked = state.gestures.holdButton;
  $("#gestureOverlayToggle").checked = state.gestures.overlay;
}

function renderPermissions() {
  Object.entries(state.permissions).forEach(([key, value]) => {
    const dot = $(`[data-status-dot="${key}"]`);
    if (dot) dot.classList.toggle("on", value);
    const input = $(`[data-permission-input="${key}"]`);
    if (input) input.checked = value;
    const card = $(`[data-permission-card="${key}"]`);
    if (card) card.classList.toggle("active", value);
  });
  const granted = Object.values(state.permissions).filter(Boolean).length;
  $("#menuPermissionSummary").textContent = `${granted}/3`;
}

function renderScrolling() {
  $("#naturalScrollToggle").checked = state.scrolling.natural;
  $("#smoothScrollToggle").checked = state.scrolling.smooth;
  $("#momentumToggle").checked = state.scrolling.momentum;
  $("#horizontalToggle").checked = state.scrolling.horizontal;
  $("#scrollSpeed").value = state.scrolling.speed;
  $("#scrollAcceleration").value = state.scrolling.acceleration;
  $("#scrollPrecision").value = state.scrolling.precision;
  $("#speedOutput").textContent = `${state.scrolling.speed}%`;
  $("#accelOutput").textContent = `${state.scrolling.acceleration}%`;
  $("#precisionOutput").textContent = state.scrolling.precision;
  $("#scrollMetric").textContent = `${state.scrolling.smoothness}%`;
  $("#scrollPreview").classList.toggle("no-smooth", !state.scrolling.smooth);
  $$("#smoothnessControl .segment").forEach((button) => {
    button.classList.toggle("active", Number(button.dataset.smoothness) === state.scrolling.smoothness);
  });
}

function renderMenubar() {
  $("#launchAtLoginToggle").checked = state.menubar.launchAtLogin;
  $("#menuIconToggle").checked = state.menubar.menuIcon;
  $("#notificationsToggle").checked = state.menubar.notifications;
  $("#autoUpdatesToggle").checked = state.menubar.autoUpdates;
}

function renderLicense() {
  $("#licenseInput").value = state.license.key;
  $("#trialDays").textContent = state.license.activated ? "∞" : String(state.license.trialDays);
  const badge = $("#licenseBadge");
  badge.textContent = state.license.activated ? "Activated" : "Trial";
  badge.classList.toggle("activated", state.license.activated);

  const radius = 48;
  const circumference = Math.round(2 * Math.PI * radius);
  const remaining = state.license.activated ? 1 : Math.max(0, Math.min(1, state.license.trialDays / 14));
  $("#trialMeter").style.strokeDasharray = String(circumference);
  $("#trialMeter").style.strokeDashoffset = String(circumference * (1 - remaining));
}

function renderLog() {
  const log = $("#eventLog");
  if (!state.log.length) {
    log.innerHTML = `<li class="empty-state">No events yet</li>`;
    return;
  }
  log.innerHTML = state.log
    .map(
      (item) => `
        <li>
          <span>${escapeHtml(item.time)}</span>
          <span><strong>${escapeHtml(item.title)}</strong><br />${escapeHtml(item.detail)}</span>
        </li>
      `,
    )
    .join("");
}

function renderScreen() {
  $$(".space-strip span").forEach((item) => {
    item.classList.toggle("active", Number(item.dataset.space) === state.currentSpace);
  });
}

function playControl(controlId) {
  if (!state.enabled) {
    showToast("Mouse Fix is off", "Enable the app to run mappings.");
    return;
  }
  const profile = activeProfile();
  const mapping = profile.mappings[controlId] || { action: "None", value: "" };
  playAction(mapping, controlLabel(controlId));
  highlightControl(controlId);
}

function playGesture(buttonId, direction) {
  if (!state.enabled) {
    showToast("Mouse Fix is off", "Enable the app to run gestures.");
    return;
  }
  const profile = activeProfile();
  const mapping = profile.gestures?.[buttonId]?.[direction] || { action: "None", value: "" };
  playAction(mapping, `${controlLabel(buttonId)} ${direction}`);
}

function controlLabel(controlId) {
  return controls.find((control) => control.id === controlId)?.name || controlId;
}

function playAction(mapping, source) {
  const action = mapping.action;
  let detail = source;
  const screen = $("#screenPreview");
  screen.classList.remove("mission", "desktop");

  if (mapping.value) detail += ` -> ${mapping.value}`;
  if (action === "None") {
    updateActionDisplay("No Action", detail, "○");
  } else if (action === "Move Space Left") {
    state.currentSpace = Math.max(1, state.currentSpace - 1);
    updateActionDisplay(action, `Space ${state.currentSpace}`, "←");
  } else if (action === "Move Space Right") {
    state.currentSpace = Math.min(3, state.currentSpace + 1);
    updateActionDisplay(action, `Space ${state.currentSpace}`, "→");
  } else if (action === "Mission Control") {
    screen.classList.add("mission");
    updateActionDisplay(action, detail, "⌂");
  } else if (action === "Show Desktop") {
    screen.classList.add("desktop");
    updateActionDisplay(action, detail, "▭");
  } else if (action === "Launchpad") {
    $("#previewTitle").textContent = "Launchpad";
    updateActionDisplay(action, detail, "▦");
  } else if (action === "App Expose") {
    $("#previewTitle").textContent = "App Expose";
    screen.classList.add("mission");
    updateActionDisplay(action, detail, "▤");
  } else if (action === "Open Application") {
    $("#previewTitle").textContent = mapping.value || "Application";
    updateActionDisplay(action, mapping.value || source, "↗");
  } else if (action === "Keyboard Shortcut") {
    updateActionDisplay(mapping.value || "Keyboard Shortcut", source, "⌘");
  } else {
    updateActionDisplay(action, detail, actionIcon(action));
  }

  renderScreen();
  saveState();
  logEvent(action, detail);
}

function actionIcon(action) {
  if (action === "Back") return "←";
  if (action === "Forward") return "→";
  if (action === "Smart Zoom" || action === "Zoom") return "+";
  if (action === "Quick Look") return "⌕";
  if (action === "Horizontal Scroll") return "↔";
  return "◉";
}

function updateActionDisplay(title, detail, icon) {
  $("#actionDisplay").innerHTML = `
    <span class="action-icon">${escapeHtml(icon)}</span>
    <strong>${escapeHtml(title)}</strong>
    <span>${escapeHtml(detail)}</span>
  `;
}

function highlightControl(controlId) {
  const zone = $(`.hit-zone[data-control="${controlId}"]`);
  if (!zone) return;
  zone.classList.add("active");
  window.setTimeout(() => zone.classList.remove("active"), 220);
}

function setMapping(controlId, action) {
  const profile = activeProfile();
  if (!profile.mappings[controlId]) profile.mappings[controlId] = { action: "None", value: "" };
  profile.mappings[controlId].action = action;
  if (!needsValue(action)) profile.mappings[controlId].value = "";
  saveState();
  renderButtonTable();
}

function setGesture(direction, action) {
  const profile = activeProfile();
  const buttonId = state.selectedGestureEditor;
  if (!profile.gestures[buttonId]) profile.gestures[buttonId] = {};
  if (!profile.gestures[buttonId][direction]) {
    profile.gestures[buttonId][direction] = { action: "None", value: "" };
  }
  profile.gestures[buttonId][direction].action = action;
  if (!needsValue(action)) profile.gestures[buttonId][direction].value = "";
  saveState();
  renderGestureEditor();
}

function setProfilePreset(type) {
  const profile = activeProfile();
  const presets = {
    productivity: {
      middle: "Mission Control",
      button4: "Back",
      button5: "Forward",
    },
    spaces: {
      middle: "Launchpad",
      button4: "Move Space Left",
      button5: "Move Space Right",
    },
    defaults: {
      left: "Primary Click",
      right: "Secondary Click",
      middle: "Middle Click",
      button4: "Back",
      button5: "Forward",
    },
  };
  Object.entries(presets[type]).forEach(([controlId, action]) => {
    profile.mappings[controlId] = { action, value: "" };
  });
  saveState();
  renderButtonTable();
  showToast("Preset applied", profile.name);
}

function duplicateActiveProfile() {
  const profile = clone(activeProfile());
  profile.id = uniqueId("profile");
  profile.name = `${profile.name} Copy`;
  profile.fallback = false;
  profile.bundle = "com.example.app";
  state.profiles.push(profile);
  state.activeProfileId = profile.id;
  state.editorProfileId = profile.id;
  saveState();
  render();
  logEvent("Duplicated profile", profile.name);
}

function uniqueId(prefix) {
  return `${prefix}-${Math.random().toString(36).slice(2, 8)}`;
}

function addProfile() {
  const base = clone(activeProfile());
  base.id = uniqueId("profile");
  base.name = "New Profile";
  base.bundle = "com.example.app";
  base.fallback = false;
  state.profiles.push(base);
  state.editorProfileId = base.id;
  saveState();
  render();
}

function saveEditedProfile() {
  const profile = editorProfile();
  profile.name = $("#profileNameInput").value.trim() || "Untitled";
  profile.bundle = $("#profileBundleInput").value.trim() || "*";
  profile.fallback = $("#fallbackProfileToggle").checked;
  if (profile.fallback) {
    state.profiles.forEach((item) => {
      if (item.id !== profile.id) item.fallback = false;
    });
  }
  saveState();
  render();
  showToast("Profile saved", profile.name);
}

function deleteEditedProfile() {
  const profile = editorProfile();
  if (profile.id === "global") return;
  state.profiles = state.profiles.filter((item) => item.id !== profile.id);
  if (state.activeProfileId === profile.id) state.activeProfileId = "global";
  state.editorProfileId = state.activeProfileId;
  saveState();
  render();
  showToast("Profile deleted", profile.name);
}

function exportSettings() {
  const payload = JSON.stringify(state, null, 2);
  const blob = new Blob([payload], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "mac-mouse-fix-pro-settings.json";
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
  logEvent("Exported settings", "JSON backup");
}

function importSettings(file) {
  const reader = new FileReader();
  reader.addEventListener("load", () => {
    try {
      state = normalizeState(JSON.parse(String(reader.result)));
      saveState();
      render();
      showToast("Settings imported", file.name);
      logEvent("Imported settings", file.name);
    } catch {
      showToast("Import failed", "The selected file is not valid JSON.");
    }
  });
  reader.readAsText(file);
}

function resetSettings() {
  state = clone(defaultState);
  saveState();
  render();
  showToast("Reset complete", "Default settings restored.");
}

function spinWheel() {
  const preview = $("#scrollPreview");
  const direction = state.scrolling.natural ? -1 : 1;
  const delta = direction * (state.scrolling.speed + state.scrolling.acceleration);
  const precision = Math.max(1, state.scrolling.precision);
  preview.scrollTop += delta * precision * 0.45;
  updateActionDisplay("Smooth Scroll", `${state.scrolling.speed}% speed`, "⇅");
  logEvent("Smooth Scroll", `${state.scrolling.smoothness}% smoothness`);
}

function setShortcutRecording(input) {
  recordingTarget = input;
  input.value = "Press shortcut...";
  input.focus();
}

function shortcutFromEvent(event) {
  const parts = [];
  if (event.metaKey) parts.push("Command");
  if (event.ctrlKey) parts.push("Control");
  if (event.altKey) parts.push("Option");
  if (event.shiftKey) parts.push("Shift");
  const key = event.key.length === 1 ? event.key.toUpperCase() : event.key;
  if (!["Meta", "Control", "Alt", "Shift"].includes(event.key)) parts.push(key);
  return parts.join(" + ");
}

function bindEvents() {
  $$(".nav-item").forEach((button) => {
    button.addEventListener("click", () => switchSection(button.dataset.section));
  });

  $$("[data-section-link]").forEach((button) => {
    button.addEventListener("click", () => switchSection(button.dataset.sectionLink));
  });

  $$(".segment[data-enabled]").forEach((button) => {
    button.addEventListener("click", () => {
      state.enabled = button.dataset.enabled === "true";
      saveState();
      renderSections();
      showToast(state.enabled ? "Mouse Fix enabled" : "Mouse Fix disabled");
    });
  });

  $("#profileSelect").addEventListener("change", (event) => {
    state.activeProfileId = event.target.value;
    state.editorProfileId = event.target.value;
    saveState();
    render();
  });

  $("#deviceSelect").addEventListener("change", (event) => {
    state.device = event.target.value;
    saveState();
    render();
  });

  $("#buttonTable").addEventListener("change", (event) => {
    const select = event.target.closest("[data-action-select]");
    const valueInput = event.target.closest("[data-value-input]");
    if (select) setMapping(select.dataset.actionSelect, select.value);
    if (valueInput) {
      const profile = activeProfile();
      profile.mappings[valueInput.dataset.valueInput].value = valueInput.value;
      saveState();
    }
  });

  $("#buttonTable").addEventListener("click", (event) => {
    const test = event.target.closest("[data-test-control]");
    const shortcutInput = event.target.closest("[data-value-input]");
    if (test) playControl(test.dataset.testControl);
    if (shortcutInput && shortcutInput.placeholder.includes("press keys")) {
      setShortcutRecording(shortcutInput);
    }
  });

  $$(".hit-zone").forEach((button) => {
    button.addEventListener("click", () => playControl(button.dataset.control));
  });

  $("#presetProductivity").addEventListener("click", () => setProfilePreset("productivity"));
  $("#presetSpaces").addEventListener("click", () => setProfilePreset("spaces"));
  $("#presetDefaults").addEventListener("click", () => setProfilePreset("defaults"));
  $("#duplicateProfileButton").addEventListener("click", duplicateActiveProfile);

  $$("#gestureButtonGroup .small-button").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedGestureButton = button.dataset.gestureButton;
      saveState();
      renderSections();
    });
  });

  $$("[data-gesture-editor]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedGestureEditor = button.dataset.gestureEditor;
      saveState();
      render();
    });
  });

  $("#gestureEditor").addEventListener("change", (event) => {
    const select = event.target.closest("[data-gesture-select]");
    const valueInput = event.target.closest("[data-gesture-value]");
    if (select) setGesture(select.dataset.gestureSelect, select.value);
    if (valueInput) {
      const profile = activeProfile();
      const buttonId = state.selectedGestureEditor;
      profile.gestures[buttonId][valueInput.dataset.gestureValue].value = valueInput.value;
      saveState();
    }
  });

  $("#gestureEditor").addEventListener("click", (event) => {
    const test = event.target.closest("[data-test-gesture]");
    const shortcutInput = event.target.closest("[data-gesture-value]");
    if (test) playGesture(state.selectedGestureEditor, test.dataset.testGesture);
    if (shortcutInput && shortcutInput.placeholder.includes("press keys")) {
      setShortcutRecording(shortcutInput);
    }
  });

  bindGesturePad();
  bindScrollSettings();
  bindPermissions();
  bindProfiles();
  bindMenubar();
  bindLicense();

  $("#clearLogButton").addEventListener("click", () => {
    state.log = [];
    saveState();
    renderLog();
  });
  $("#spinWheelButton").addEventListener("click", spinWheel);
  $("#scrollPreview").addEventListener("wheel", () => {
    updateActionDisplay("Wheel Input", "Preview scrolled", "⇅");
  });

  $("#importButton").addEventListener("click", () => $("#importFile").click());
  $("#importFile").addEventListener("change", (event) => {
    const [file] = event.target.files || [];
    if (file) importSettings(file);
    event.target.value = "";
  });
  $("#exportButton").addEventListener("click", exportSettings);
  $("#themeButton").addEventListener("click", () => {
    state.theme = state.theme === "dark" ? "light" : "dark";
    saveState();
    render();
  });
  $("#resetButton").addEventListener("click", resetSettings);

  $("#commandSearch").addEventListener("input", (event) => filterSettings(event.target.value));

  document.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault();
      $("#commandSearch").focus();
      return;
    }
    if (recordingTarget) {
      event.preventDefault();
      const shortcut = shortcutFromEvent(event);
      if (!shortcut) return;
      recordingTarget.value = shortcut;
      recordingTarget.dispatchEvent(new Event("change", { bubbles: true }));
      recordingTarget = null;
      showToast("Shortcut recorded", shortcut);
    }
  });
}

function bindGesturePad() {
  const pad = $("#gesturePad");
  const cursor = $("#gestureCursor");

  pad.addEventListener("pointerdown", (event) => {
    const rect = pad.getBoundingClientRect();
    dragStart = {
      x: event.clientX,
      y: event.clientY,
      rect,
    };
    pad.setPointerCapture(event.pointerId);
    pad.classList.add("dragging");
    moveGestureCursor(event);
  });

  pad.addEventListener("pointermove", (event) => {
    if (!dragStart) return;
    moveGestureCursor(event);
  });

  pad.addEventListener("pointerup", (event) => {
    if (!dragStart) return;
    const dx = event.clientX - dragStart.x;
    const dy = event.clientY - dragStart.y;
    const direction = detectDirection(dx, dy);
    pad.classList.remove("dragging");
    cursor.style.opacity = "";
    dragStart = null;
    clearDirectionHighlight();
    if (direction) playGesture(state.selectedGestureButton, direction);
  });

  pad.addEventListener("pointercancel", () => {
    dragStart = null;
    pad.classList.remove("dragging");
    clearDirectionHighlight();
  });
}

function moveGestureCursor(event) {
  const pad = $("#gesturePad");
  const cursor = $("#gestureCursor");
  const rect = pad.getBoundingClientRect();
  const x = Math.min(Math.max(event.clientX - rect.left, 0), rect.width);
  const y = Math.min(Math.max(event.clientY - rect.top, 0), rect.height);
  cursor.style.left = `${x}px`;
  cursor.style.top = `${y}px`;

  if (!dragStart) return;
  const direction = detectDirection(event.clientX - dragStart.x, event.clientY - dragStart.y);
  highlightDirection(direction);
}

function detectDirection(dx, dy) {
  if (Math.hypot(dx, dy) < state.gestures.threshold) return null;
  if (Math.abs(dx) > Math.abs(dy)) return dx > 0 ? "right" : "left";
  return dy > 0 ? "down" : "up";
}

function highlightDirection(direction) {
  clearDirectionHighlight();
  if (!direction || !state.gestures.overlay) return;
  const node = $(`.gesture-cross [data-direction="${direction}"]`);
  if (node) node.classList.add("active");
}

function clearDirectionHighlight() {
  $$(".gesture-cross span").forEach((node) => node.classList.remove("active"));
}

function bindScrollSettings() {
  const checkboxBindings = [
    ["naturalScrollToggle", "natural"],
    ["smoothScrollToggle", "smooth"],
    ["momentumToggle", "momentum"],
    ["horizontalToggle", "horizontal"],
  ];
  checkboxBindings.forEach(([id, key]) => {
    $(`#${id}`).addEventListener("change", (event) => {
      state.scrolling[key] = event.target.checked;
      saveState();
      renderScrolling();
    });
  });

  const rangeBindings = [
    ["scrollSpeed", "speed"],
    ["scrollAcceleration", "acceleration"],
    ["scrollPrecision", "precision"],
  ];
  rangeBindings.forEach(([id, key]) => {
    $(`#${id}`).addEventListener("input", (event) => {
      state.scrolling[key] = Number(event.target.value);
      saveState();
      renderScrolling();
    });
  });

  $("#smoothnessControl").addEventListener("click", (event) => {
    const button = event.target.closest("[data-smoothness]");
    if (!button) return;
    state.scrolling.smoothness = Number(button.dataset.smoothness);
    state.scrolling.smooth = state.scrolling.smoothness > 0;
    saveState();
    renderScrolling();
  });

  $("#gestureThreshold").addEventListener("input", (event) => {
    state.gestures.threshold = Number(event.target.value);
    saveState();
    renderGestureEditor();
  });
  $("#holdGestureToggle").addEventListener("change", (event) => {
    state.gestures.holdButton = event.target.checked;
    saveState();
  });
  $("#gestureOverlayToggle").addEventListener("change", (event) => {
    state.gestures.overlay = event.target.checked;
    saveState();
  });
}

function bindPermissions() {
  $$("[data-permission-input]").forEach((input) => {
    input.addEventListener("change", () => {
      state.permissions[input.dataset.permissionInput] = input.checked;
      saveState();
      renderPermissions();
    });
  });

  $$("[data-toggle-permission]").forEach((button) => {
    button.addEventListener("click", () => {
      const key = button.dataset.togglePermission;
      state.permissions[key] = !state.permissions[key];
      saveState();
      renderPermissions();
      showToast(`${keyLabel(key)} ${state.permissions[key] ? "enabled" : "disabled"}`);
    });
  });

  $("#grantAllButton").addEventListener("click", () => {
    Object.keys(state.permissions).forEach((key) => {
      state.permissions[key] = true;
    });
    saveState();
    renderPermissions();
    showToast("Permissions granted", "Simulated system state");
  });
}

function keyLabel(key) {
  return key.replace(/[A-Z]/g, (match) => ` ${match}`).replace(/^./, (match) => match.toUpperCase());
}

function bindProfiles() {
  $("#profileList").addEventListener("click", (event) => {
    const card = event.target.closest("[data-edit-profile]");
    if (!card) return;
    state.editorProfileId = card.dataset.editProfile;
    saveState();
    renderProfiles();
  });

  $("#addProfileButton").addEventListener("click", addProfile);
  $("#saveProfileButton").addEventListener("click", saveEditedProfile);
  $("#deleteProfileButton").addEventListener("click", deleteEditedProfile);
}

function bindMenubar() {
  const bindings = [
    ["launchAtLoginToggle", "launchAtLogin"],
    ["menuIconToggle", "menuIcon"],
    ["notificationsToggle", "notifications"],
    ["autoUpdatesToggle", "autoUpdates"],
  ];
  bindings.forEach(([id, key]) => {
    $(`#${id}`).addEventListener("change", (event) => {
      state.menubar[key] = event.target.checked;
      saveState();
    });
  });

  $("#checkUpdatesButton").addEventListener("click", () => {
    logEvent("Checked updates", "No update available");
    showToast("No update available", "Replica version 1.0.0");
  });
}

function bindLicense() {
  $("#licenseInput").addEventListener("input", (event) => {
    state.license.key = event.target.value;
    saveState();
  });

  $("#activateButton").addEventListener("click", () => {
    const key = $("#licenseInput").value.trim();
    if (!key) {
      showToast("License key required", "Enter any key to simulate activation.");
      return;
    }
    state.license.key = key;
    state.license.activated = true;
    saveState();
    renderLicense();
    logEvent("Activated license", key.slice(0, 8).padEnd(key.length, "*"));
    showToast("License activated", "Activation is simulated in this web replica.");
  });

  $("#extendTrialButton").addEventListener("click", () => {
    state.license.trialDays = Math.min(14, state.license.trialDays + 1);
    saveState();
    renderLicense();
  });
}

function switchSection(sectionId) {
  $$(".nav-item").forEach((button) => {
    button.classList.toggle("active", button.dataset.section === sectionId);
  });
  $$("[data-panel]").forEach((panel) => {
    panel.classList.toggle("active", panel.id === sectionId);
  });
  $("#commandSearch").value = "";
  filterSettings("");
}

function filterSettings(query) {
  const normalized = query.trim().toLowerCase();
  $$(".nav-item").forEach((button) => {
    const text = button.textContent.toLowerCase();
    button.hidden = normalized && !text.includes(normalized);
  });
  if (!normalized) return;
  const match = $$(".nav-item").find((button) => !button.hidden);
  if (match) switchSection(match.dataset.section);
}

bindEvents();
render();
