/* CoachRootView-port + preview-chrome.
   Beheert tabs, overlays (fullScreenCover / sheet / confirmationDialog / alert),
   de sessie-timers en het linkspaneel met live API- en device-logboek. */

import { icon } from "./icons.js";
import { api, haptic, logDevice, onApiLog, onDeviceLog } from "./api.js";
import { hourLabel, clock } from "./screens.js";
import * as views from "./screens.js";
import { store, sleep } from "./store.js";

const DEMO_EMAIL = "demo@kova.app";
const DEMO_PASSWORD = "preview1234";

const ui = {
  tab: "today",
  booting: true,
  onboardingOverlayStep: 0,
  onboarding: { step: 0, goal: "Hypertrophy", daysPerWeek: 4, equipment: "Full gym", reminderHour: 18 },
  showOnboardingCover: false,
  auth: { email: "", password: "", createAccount: true, errorText: null, isSubmitting: false },
  session: { visible: false, elapsedSeconds: 0, restSecondsRemaining: 0, activeRestExercise: null, isSessionComplete: false },
  feedback: { visible: false, rpe: 8, soreness: 2, saving: false },
  settings: { visible: false, remindersOn: false, reminderStatus: "Reminders are off", deletionPassword: "" },
  dialog: null, // 'adjustToday' | 'delete' | 'password'
  scroll: {},
  currentSource: "—",
};

const screenEl = document.getElementById("screen");
const phoneUi = document.getElementById("phone-ui");
const statusBar = document.getElementById("status-bar");
const apiLogEl = document.getElementById("api-log");
const deviceLogEl = document.getElementById("device-log");
const apiMetaEl = document.getElementById("api-meta");
const screenNavEl = document.getElementById("screen-nav");
const panelActionsEl = document.getElementById("panel-actions");
const sourceMapEl = document.getElementById("source-map");
const scaleLabelEl = document.getElementById("scale-label");

let layerRoot = document.createElement("div");
layerRoot.id = "layer-root";
layerRoot.style.cssText = "position:absolute;inset:0;z-index:40;pointer-events:none";
screenEl.appendChild(layerRoot);

/* ------------------------------------------------------------- status bar */

function renderStatusBar() {
  const time = new Date().toLocaleTimeString("nl-BE", { hour: "2-digit", minute: "2-digit", hour12: false });
  statusBar.innerHTML = `<span>${time}</span>
    <span class="sb-right">${icon("cellular", 17)}${icon("wifi", 16)}${icon("battery", 25)}</span>`;
}

/* ------------------------------------------------------------------ tabs */

const SCREENS = {
  today: () => views.todayScreen(),
  history: () => views.historyScreen(),
  plan: () => views.planScreen(),
};

const TABS = [
  { id: "today", label: "Coach", icon: "dumbbell" },
  { id: "history", label: "History", icon: "clock-rotate" },
  { id: "plan", label: "Plan", icon: "calendar" },
];

function captureScroll(root) {
  root.querySelectorAll(".scroll[data-scroll]").forEach((el) => {
    ui.scroll[el.dataset.scroll] = el.scrollTop;
  });
}

function restoreScroll(root) {
  root.querySelectorAll(".scroll[data-scroll]").forEach((el) => {
    const saved = ui.scroll[el.dataset.scroll];
    if (saved) el.scrollTop = saved;
  });
}

function renderTabs() {
  captureScroll(phoneUi);
  const screen = SCREENS[ui.tab]();
  ui.currentSource = screen.source;

  phoneUi.innerHTML = `<div class="tab-content">${screen.html}</div>
    <div class="tab-bar">${TABS.map(
      (tab) => `<button class="tab-item ${tab.id === ui.tab ? "active" : ""}" data-action="tab" data-tab="${tab.id}">
        ${icon(tab.icon, 25)}<span>${tab.label}</span>
      </button>`
    ).join("")}</div>`;

  restoreScroll(phoneUi);
  autofit(phoneUi);
}

/* ---------------------------------------------------------------- layers */

function overlayState() {
  return {
    onboardingRoot: !store.hasCompletedOnboarding,
    authRoot: store.hasCompletedOnboarding && !store.isAuthenticated,
  };
}

function renderLayers({ animate = true } = {}) {
  captureScroll(layerRoot);
  const { onboardingRoot, authRoot } = overlayState();
  const parts = [];

  if (ui.booting) {
    /* UILaunchScreen_Generation = YES → zwart launch screen tot de sessie hersteld is */
    parts.push(`<div class="cover no-anim launch"><span class="t-display">KOVA</span></div>`);
  }

  if (onboardingRoot) parts.push(views.onboardingScreen(ui.onboarding, { animated: false }).html);
  if (ui.showOnboardingCover) parts.push(views.onboardingScreen(ui.onboarding, { animated: animate }).html);
  if (authRoot) parts.push(views.authScreen(ui.auth, { animated: false }).html);
  if (ui.authFromOnboarding) parts.push(views.authScreen(ui.auth, { animated: animate }).html);
  if (ui.session.visible) parts.push(views.sessionScreen(ui.session).html);
  if (ui.settings.visible) parts.push(views.settingsSheet(ui.settings).html);
  if (ui.feedback.visible) parts.push(views.feedbackSheet(ui.feedback).html);
  if (ui.dialog === "adjustToday") parts.push(views.adjustTodayDialog().html);
  if (ui.dialog === "delete") parts.push(views.deleteAccountAlert().html);
  if (ui.dialog === "password") parts.push(views.passwordAlert(ui.settings.deletionPassword).html);

  const anyCover = onboardingRoot || ui.showOnboardingCover || authRoot || ui.authFromOnboarding || ui.session.visible;
  const tabBar = phoneUi.querySelector(".tab-bar");
  if (tabBar) tabBar.style.display = anyCover ? "none" : "flex";

  const source = parts.length
    ? [
        ui.dialog === "adjustToday" && "TodayView.swift · confirmationDialog",
        (ui.dialog === "delete" || ui.dialog === "password") && "SettingsView.swift · alert",
        ui.feedback.visible && "SessionView.swift · FeedbackView",
        ui.settings.visible && "SettingsView.swift",
        ui.session.visible && "SessionView.swift",
        (ui.authFromOnboarding || authRoot) && "AuthenticationView.swift",
        (ui.showOnboardingCover || onboardingRoot) && "OnboardingView.swift",
      ].filter(Boolean)[0]
    : null;
  if (source) ui.currentSource = `ios/KOVAAi/Views/${source}`;

  layerRoot.innerHTML = parts.join("");
  layerRoot.style.pointerEvents = parts.length ? "auto" : "none";
  restoreScroll(layerRoot);
  autofit(layerRoot);
  if (ui.onboarding.step === 3 || (ui.showOnboardingCover && ui.onboarding.step === 3)) initWheel();
  updateSourceMap();
  updateScreenNav();
}

function render() {
  renderTabs();
  renderLayers();
}

function autofit(root) {
  root.querySelectorAll(".autofit").forEach((el) => {
    const lines = Number(el.dataset.lines || 2);
    let size = 52;
    el.style.fontSize = `${size}px`;
    let guard = 0;
    while (el.scrollHeight > lines * size * 1.06 + 1 && size > 28 && guard < 14) {
      size -= 2;
      el.style.fontSize = `${size}px`;
      guard += 1;
    }
  });
}

/* ------------------------------------------------------------ wheel picker */

function initWheel() {
  const scroller = document.getElementById("reminder-wheel");
  if (!scroller || scroller.dataset.bound === "true") return;
  scroller.dataset.bound = "true";
  const itemHeight = 40;
  const index = ui.onboarding.reminderHour - 6;
  scroller.scrollTop = index * itemHeight;
  let frame = null;
  scroller.addEventListener(
    "scroll",
    () => {
      if (frame) cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const picked = Math.round(scroller.scrollTop / itemHeight) + 6;
        if (picked !== ui.onboarding.reminderHour) {
          ui.onboarding.reminderHour = Math.min(21, Math.max(6, picked));
          scroller.querySelectorAll(".wheel-item").forEach((item) => {
            item.classList.toggle("selected", Number(item.dataset.hour) === ui.onboarding.reminderHour);
          });
        }
      });
    },
    { passive: true }
  );
}

/* --------------------------------------------------------------- timers */

let ticker = null;

function ensureTicker() {
  if (ticker) return;
  ticker = setInterval(() => {
    if (!ui.session.visible) return;
    ui.session.elapsedSeconds += 1;
    const elapsedEl = document.getElementById("elapsed-timer");
    if (elapsedEl) elapsedEl.textContent = clock(ui.session.elapsedSeconds);

    if (ui.session.restSecondsRemaining > 0) {
      ui.session.restSecondsRemaining -= 1;
      const restEl = document.getElementById("rest-time");
      if (restEl) restEl.textContent = clock(ui.session.restSecondsRemaining);
      if (ui.session.restSecondsRemaining === 0) {
        ui.session.activeRestExercise = null;
        haptic("restFinished");
        renderLayers({ animate: false });
      }
    }
  }, 1000);
}

function closeLayer(selector, done) {
  const el = layerRoot.querySelector(selector);
  if (!el) {
    done();
    return;
  }
  el.classList.add("closing");
  setTimeout(done, 260);
}

/* --------------------------------------------------------------- actions */

async function ensureDemoSession() {
  if (store.isAuthenticated) return true;
  try {
    await store.signIn(DEMO_EMAIL, DEMO_PASSWORD, false);
  } catch {
    try {
      await store.signIn(DEMO_EMAIL, DEMO_PASSWORD, true);
    } catch (error) {
      logDevice("TenxSession", `demo-account mislukt: ${error.message}`);
      return false;
    }
  }
  store.setOnboardingDone(true);
  logDevice("Preview", `demo-sessie gestart als ${DEMO_EMAIL}`);
  return true;
}

function openSession() {
  store.resetActiveSession();
  ui.session = {
    visible: true,
    elapsedSeconds: 0,
    restSecondsRemaining: 0,
    activeRestExercise: null,
    isSessionComplete: false,
  };
  ensureTicker();
  renderLayers();
}

function closeSession() {
  ui.session.visible = false;
  ui.feedback.visible = false;
  ui.session.restSecondsRemaining = 0;
  store.resetActiveSession();
}

async function onboardingAdvance() {
  if (ui.onboarding.step < 3) {
    ui.onboarding.step += 1;
    haptic("selection");
    renderLayers({ animate: false });
    return;
  }
  store.updateProfile({
    goal: ui.onboarding.goal,
    days: ui.onboarding.daysPerWeek,
    equipment: ui.onboarding.equipment,
    hour: ui.onboarding.reminderHour,
    minute: 0,
  });
  logDevice("Notifications", `scheduleDailyReminder(${ui.onboarding.reminderHour}:00) → gesimuleerd`);
  ui.auth = { email: "", password: "", createAccount: true, errorText: null, isSubmitting: false };
  ui.authFromOnboarding = true;
  renderLayers();
}

async function authSubmit() {
  const email = ui.auth.email.trim();
  if (!email || ui.auth.password.length < 8 || ui.auth.isSubmitting) return;
  ui.auth.isSubmitting = true;
  ui.auth.errorText = null;
  renderLayers({ animate: false });
  try {
    await store.signIn(email, ui.auth.password, ui.auth.createAccount);
    if (ui.authFromOnboarding) {
      haptic("setCompleted");
      ui.authFromOnboarding = false;
      store.setOnboardingDone(true);
    }
    ui.auth.isSubmitting = false;
    ui.auth.password = "";
    render();
    refreshFacts();
  } catch (error) {
    ui.auth.isSubmitting = false;
    ui.auth.errorText = error.message;
    renderLayers({ animate: false });
  }
}

async function saveFeedback() {
  if (ui.feedback.saving) return;
  ui.feedback.saving = true;
  const elapsedMinutes = Math.max(Math.floor(ui.session.elapsedSeconds / 60), 1);
  const ok = await store.finishWorkout({
    rpe: ui.feedback.rpe,
    soreness: ui.feedback.soreness,
    elapsedMinutes,
  });
  ui.feedback.saving = false;
  if (!ok || store.backendError) {
    renderLayers({ animate: false });
    return;
  }
  haptic("setCompleted");
  closeLayer('.sheet[data-sheet="feedback"]', () => {
    closeLayer('.cover[data-cover="session"]', () => {
      closeSession();
      render();
      refreshFacts();
    });
  });
}

async function toggleReminders() {
  ui.settings.remindersOn = !ui.settings.remindersOn;
  if (!ui.settings.remindersOn) {
    ui.settings.reminderStatus = "Reminders are off";
    renderLayers({ animate: false });
    return;
  }
  const hour = store.profile.reminderHour;
  try {
    await api.put("/api/v1/reminder", { reminder_hour: hour, reminder_minute: 0 });
    ui.settings.reminderStatus = `Daily reminder scheduled for ${hourLabel(hour)}`;
    logDevice("Notifications", `UNCalendarNotificationTrigger daily ${hour}:00 → granted (gesimuleerd)`);
  } catch (error) {
    ui.settings.remindersOn = false;
    ui.settings.reminderStatus = "Notifications are unavailable. Enable them in Settings.";
    logDevice("Notifications", error.message);
  }
  renderLayers({ animate: false });
}

async function deleteAccount() {
  const password = ui.settings.deletionPassword;
  await store.deleteAccount(password);
  ui.dialog = null;
  ui.settings.deletionPassword = "";
  if (store.isAuthenticated) {
    /* mislukt: SettingsView blijft open en toont backendError, net als in Swift */
    renderLayers({ animate: false });
    return;
  }
  ui.settings.visible = false;
  store.setOnboardingDone(false);
  ui.onboarding = { step: 0, goal: "Hypertrophy", daysPerWeek: 4, equipment: "Full gym", reminderHour: 18 };
  render();
  refreshFacts();
}

const ACTIONS = {
  tab: (el) => {
    ui.tab = el.dataset.tab;
    haptic("selection");
    render();
  },
  "day-prev": () => {
    store.selectedDateOffset -= 1;
    haptic("selection");
    renderTabs();
  },
  "day-next": () => {
    store.selectedDateOffset += 1;
    haptic("selection");
    renderTabs();
  },
  "day-today": () => {
    store.selectedDateOffset = 0;
    haptic("selection");
    renderTabs();
  },
  "open-settings": () => {
    ui.settings.visible = true;
    renderLayers();
  },
  "close-settings": () => {
    closeLayer('.sheet[data-sheet="settings"]', () => {
      ui.settings.visible = false;
      renderLayers({ animate: false });
    });
  },
  "start-session": () => {
    haptic("selection");
    openSession();
  },
  "end-session": () => {
    closeLayer('.cover[data-cover="session"]', () => {
      closeSession();
      render();
    });
  },
  "adjust-today": () => {
    ui.dialog = "adjustToday";
    renderLayers();
  },
  "close-dialog": () => {
    ui.dialog = null;
    renderLayers({ animate: false });
  },
  "swap-focus": () => {
    store.swapRecommendation();
    ui.dialog = null;
    render();
  },
  "regenerate-volume": () => {
    store.regenerateRecommendation();
    ui.dialog = null;
    render();
  },
  "log-set": (el) => {
    const exercise = store.recommendedWorkout.exercises.find((item) => item.id === el.dataset.exercise);
    if (!exercise) return;
    store.markSetComplete(exercise);
    ui.session.activeRestExercise = exercise;
    ui.session.restSecondsRemaining = exercise.restSeconds;
    ui.session.isSessionComplete = store.completedSets.length === store.totalSets;
    renderLayers({ animate: false });
  },
  "skip-rest": () => {
    ui.session.restSecondsRemaining = 0;
    ui.session.activeRestExercise = null;
    haptic("selection");
    renderLayers({ animate: false });
  },
  "open-feedback": () => {
    ui.feedback.visible = true;
    ui.feedback.rpe = 8;
    ui.feedback.soreness = 2;
    renderLayers();
  },
  "set-rpe": (el) => {
    ui.feedback.rpe = Number(el.dataset.score);
    haptic("selection");
    renderLayers({ animate: false });
  },
  "set-soreness": (el) => {
    ui.feedback.soreness = Number(el.dataset.score);
    haptic("selection");
    renderLayers({ animate: false });
  },
  "save-feedback": saveFeedback,
  "sign-out": async () => {
    await store.signOut();
    ui.settings.visible = false;
    /* AuthenticationView wordt opnieuw aangemaakt → verse @State, net als in SwiftUI */
    ui.auth = { email: "", password: "", createAccount: true, errorText: null, isSubmitting: false };
    render();
  },
  "rebuild-profile": () => {
    ui.settings.visible = false;
    ui.onboarding = { step: 0, goal: store.profile.goal, daysPerWeek: store.profile.daysPerWeek, equipment: store.profile.equipment, reminderHour: store.profile.reminderHour };
    ui.showOnboardingCover = true;
    renderLayers();
  },
  "connect-health": () => store.connectAppleHealth(),
  "toggle-reminders": toggleReminders,
  "refresh-data": async () => {
    await store.refreshRemoteState();
    render();
    refreshFacts();
  },
  "export-data": () => store.exportTrainingSummary(),
  "ask-delete-account": () => {
    ui.dialog = "delete";
    renderLayers();
  },
  "confirm-delete": () => {
    ui.dialog = "password";
    ui.settings.deletionPassword = "";
    renderLayers({ animate: false });
    setTimeout(() => document.getElementById("delete-password")?.focus(), 60);
  },
  "delete-account": deleteAccount,
  "onboarding-continue": onboardingAdvance,
  "set-goal": (el) => {
    ui.onboarding.goal = el.dataset.value;
    haptic("selection");
    renderLayers({ animate: false });
  },
  "set-days": (el) => {
    ui.onboarding.daysPerWeek = Number(el.dataset.value);
    haptic("selection");
    renderLayers({ animate: false });
  },
  "set-equipment": (el) => {
    ui.onboarding.equipment = el.dataset.value;
    haptic("selection");
    renderLayers({ animate: false });
  },
  "auth-toggle": () => {
    ui.auth.createAccount = !ui.auth.createAccount;
    ui.auth.errorText = null;
    renderLayers({ animate: false });
    setTimeout(() => document.getElementById("auth-email")?.focus(), 60);
  },
  "auth-submit": authSubmit,
};

/* delegated click handling inside the phone */
screenEl.addEventListener("click", (event) => {
  const target = event.target.closest("[data-action]");
  if (!target || !screenEl.contains(target)) return;
  const handler = ACTIONS[target.dataset.action];
  if (handler) {
    event.preventDefault();
    handler(target, event);
  }
});

/* input handling that must not re-render (focus behouden) */
screenEl.addEventListener("input", (event) => {
  const target = event.target;
  if (target.id === "auth-email") {
    ui.auth.email = target.value;
    const button = document.getElementById("auth-submit");
    if (button) button.disabled = ui.auth.isSubmitting || !ui.auth.email.trim() || ui.auth.password.length < 8;
  } else if (target.id === "auth-password") {
    ui.auth.password = target.value;
    const button = document.getElementById("auth-submit");
    if (button) button.disabled = ui.auth.isSubmitting || !ui.auth.email.trim() || ui.auth.password.length < 8;
  } else if (target.id === "delete-password") {
    ui.settings.deletionPassword = target.value;
  }
});

screenEl.addEventListener("keydown", (event) => {
  if (event.key !== "Enter") return;
  if (event.target.id === "auth-email" || event.target.id === "auth-password") authSubmit();
  if (event.target.id === "delete-password") deleteAccount();
});

/* store changes → rerender */
store.subscribe((reason) => {
  if (reason === "set") {
    /* set-chips worden expliciet opnieuw gerenderd door de actie */
    return;
  }
  if (reason === "sync") {
    renderTabs();
    if (ui.settings.visible) renderLayers({ animate: false });
    return;
  }
  render();
});

/* --------------------------------------------------------------- chrome */

const NAV_ITEMS = [
  { id: "onboarding", label: "Onboarding", file: "OnboardingView.swift", icon: "sparkles" },
  { id: "auth", label: "Sign in", file: "AuthenticationView.swift", icon: "lock" },
  { id: "today", label: "Coach (Today)", file: "TodayView.swift", icon: "dumbbell" },
  { id: "history", label: "History", file: "HistoryView.swift", icon: "clock-rotate" },
  { id: "plan", label: "Plan", file: "PlanView.swift", icon: "calendar" },
  { id: "session", label: "Session", file: "SessionView.swift", icon: "play-fill" },
  { id: "settings", label: "Settings", file: "SettingsView.swift", icon: "gear" },
  { id: "feedback", label: "Session review", file: "SessionView.swift · FeedbackView", icon: "check-circle-fill" },
];

function activeNavId() {
  if (ui.dialog) return null;
  if (ui.feedback.visible) return "feedback";
  if (ui.settings.visible) return "settings";
  if (ui.session.visible) return "session";
  if (ui.authFromOnboarding) return "auth";
  if (!store.hasCompletedOnboarding || ui.showOnboardingCover) return "onboarding";
  if (!store.isAuthenticated) return "auth";
  return ui.tab;
}

function updateScreenNav() {
  const active = activeNavId();
  screenNavEl.innerHTML = NAV_ITEMS.map(
    (item) => `<button data-nav="${item.id}" class="${active === item.id ? "active" : ""}">
      ${icon(item.icon, 17)}
      <span class="nav-label"><b>${item.label}</b><span>${item.file}</span></span>
    </button>`
  ).join("");
}

screenNavEl.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-nav]");
  if (!button) return;
  const target = button.dataset.nav;
  ui.dialog = null;

  if (target === "onboarding") {
    store.setOnboardingDone(false);
    ui.showOnboardingCover = false;
    ui.authFromOnboarding = false;
    ui.session.visible = false;
    ui.settings.visible = false;
    ui.feedback.visible = false;
    ui.onboarding = { step: 0, goal: store.profile.goal, daysPerWeek: store.profile.daysPerWeek, equipment: store.profile.equipment, reminderHour: store.profile.reminderHour };
    render();
    return;
  }

  if (target === "auth") {
    ui.authFromOnboarding = false;
    ui.showOnboardingCover = false;
    ui.session.visible = false;
    ui.settings.visible = false;
    ui.feedback.visible = false;
    if (store.isAuthenticated) await store.signOut();
    store.setOnboardingDone(true);
    ui.auth = { email: "", password: "", createAccount: true, errorText: null, isSubmitting: false };
    render();
    return;
  }

  /* app-screens: zorg dat er een ingelogde demo-sessie is */
  const ready = await ensureDemoSession();
  ui.showOnboardingCover = false;
  ui.authFromOnboarding = false;
  if (!ready) {
    render();
    return;
  }
  ui.settings.visible = target === "settings";
  ui.session.visible = target === "session" || target === "feedback";
  ui.feedback.visible = target === "feedback";
  if (target === "session" || target === "feedback") openSession();
  if (target === "today" || target === "history" || target === "plan") ui.tab = target;
  render();
});

const PANEL_ACTIONS = [
  { label: "Demo-sessie starten", run: async () => { await ensureDemoSession(); render(); } },
  { label: "Demo-data resetten", run: async () => {
      if (!(await ensureDemoSession())) return render();
      await api.post("/preview/reset", {});
      await store.refreshRemoteState();
      logDevice("Preview", "demo-data opnieuw geseed (6 sessies, actief push-plan)");
      render();
      refreshFacts();
    } },
  { label: "Uitloggen", run: async () => { await store.signOut(); ui.settings.visible = false; render(); } },
  { label: "UI herladen", run: () => window.location.reload() },
];

function renderPanelActions() {
  panelActionsEl.innerHTML = PANEL_ACTIONS.map(
    (action, index) => `<button data-panel="${index}">${action.label}</button>`
  ).join("");
}

panelActionsEl.addEventListener("click", (event) => {
  const button = event.target.closest("[data-panel]");
  if (!button) return;
  PANEL_ACTIONS[Number(button.dataset.panel)].run();
});

function pushLog(container, html, cap = 40) {
  container.insertAdjacentHTML("afterbegin", html);
  while (container.children.length > cap) container.lastElementChild.remove();
}

onApiLog((entry) => {
  const cls = entry.ok ? "ok" : "err";
  pushLog(
    apiLogEl,
    `<div class="log-row ${cls}">
      <span class="method">${entry.method}</span>
      <span class="path">${entry.path}</span>
      <span class="status">${entry.status || "ERR"} · ${entry.ms}ms</span>
    </div>`
  );
});

onDeviceLog((entry) => {
  const time = entry.at.toLocaleTimeString("nl-BE", { hour12: false });
  pushLog(
    deviceLogEl,
    `<div class="log-row device">
      <span class="method">${entry.kind}</span>
      <span class="path">${entry.message}</span>
      <span class="status">${time}</span>
    </div>`,
    25
  );
});

function updateSourceMap() {
  sourceMapEl.textContent = ui.currentSource ? ` bron: ${ui.currentSource}` : "";
}

async function refreshFacts() {
  try {
    const facts = await api.get("/preview/facts", { auth: false });
    const storage = facts.storage;
    apiMetaEl.innerHTML = `FastAPI · SQLite-mirror van <code>services/db</code><br />
      ${storage.users} account(s) · ${storage.plans} plannen · ${storage.logs} logs<br />
      rotatie: ${Object.entries(facts.backend.rotation).map(([k, v]) => `${k}→${v}`).join(" ")}`;
  } catch {
    apiMetaEl.textContent = "backend niet bereikbaar";
  }
}

/* ------------------------------------------------------- device scaling */

const deviceEl = document.getElementById("device");
const deviceFit = document.getElementById("device-fit");

function fitDevice() {
  const area = document.querySelector(".device-area");
  const availableHeight = area.clientHeight - 48;
  const availableWidth = area.clientWidth - 24;
  const naturalWidth = deviceEl.offsetWidth || 426;
  const naturalHeight = deviceEl.offsetHeight || 898;
  const scale = Math.min(1, availableHeight / naturalHeight, availableWidth / naturalWidth);
  const applied = Math.max(0.32, Number.isFinite(scale) ? scale : 1);
  document.documentElement.style.setProperty("--device-scale", applied.toFixed(4));
  if (deviceFit) {
    deviceFit.style.width = `${naturalWidth * applied}px`;
    deviceFit.style.height = `${naturalHeight * applied}px`;
  }
  if (scaleLabelEl) scaleLabelEl.textContent = `${Math.round(applied * 100)}%`;
}

window.addEventListener("resize", fitDevice);

/* ------------------------------------------------------------- livereload */

let knownVersion = null;

async function pollVersion() {
  try {
    const response = await fetch("/preview/version");
    const payload = await response.json();
    window.__KOVA_VERSION = payload.version;
    if (knownVersion === null) {
      knownVersion = payload.version;
    } else if (knownVersion !== payload.version) {
      logDevice("Preview", "bron gewijzigd → UI herladen");
      window.location.reload();
      return;
    }
  } catch {
    /* server nog niet klaar */
  }
  setTimeout(pollVersion, 2500);
}

/* ------------------------------------------------------------------ boot */

async function boot() {
  renderStatusBar();
  setInterval(renderStatusBar, 15000);
  renderPanelActions();
  updateScreenNav();
  fitDevice();
  render();
  ensureTicker();
  pollVersion();
  refreshFacts();
  logDevice("Preview", "SwiftUI-render gestart (CoachRootView)");
  await store.restoreSession();
  if (store.isAuthenticated) store.setOnboardingDone(true);
  render();
  fitDevice();
  ui.booting = false;
}

boot();
