/* Renderers voor de SwiftUI-schermen. Elke functie is een 1:1 port van de
   corresponderende view in ios/KOVAAi/Views — inclusief layout, volgorde,
   teksten en tokengebruik. */

import { icon } from "./icons.js";
import { FOCUS_SYMBOL, HEALTH_STATE, store } from "./store.js";

/* --------------------------------------------------------------- formatting */

const nf = (options) => new Intl.DateTimeFormat("en-US", options);
const FMT = {
  weekdayWide: nf({ weekday: "long" }),
  weekdayNarrow: nf({ weekday: "narrow" }),
  monthDay: nf({ month: "long", day: "numeric" }),
  weekdayMonthDay: nf({ weekday: "long", month: "short", day: "numeric" }),
  hourShort: nf({ hour: "numeric", minute: "2-digit" }),
};

export const grouped = (value) => Number(value).toLocaleString("en-US");
export const hourLabel = (hour) =>
  FMT.hourShort.format(new Date(2024, 0, 1, hour, 0)).replace(/\u202f/g, " ");
export const clock = (totalSeconds) => {
  const s = Math.max(0, Math.floor(totalSeconds));
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
};

/* --------------------------------------------------------------- primitives */

export function metricLabel(label, value) {
  return `<div class="metric-label"><span class="k">${label}</span><span class="v">${value}</span></div>`;
}

export function card(content, modifier = "") {
  return `<div class="kova-card ${modifier}">${content}</div>`;
}

export function miniProgressRing(progress, value, label) {
  const clamped = Math.min(Math.max(progress, 0), 1);
  const radius = (96 - 10) / 2;
  const circumference = 2 * Math.PI * radius;
  return `<div class="ring">
    <svg viewBox="0 0 96 96">
      <circle class="ring-track" cx="48" cy="48" r="${radius}"></circle>
      <circle class="ring-value" cx="48" cy="48" r="${radius}"
        stroke-dasharray="${circumference.toFixed(2)}"
        stroke-dashoffset="${(circumference * (1 - clamped)).toFixed(2)}"></circle>
    </svg>
    <div class="ring-label"><b>${value}</b><span>${label}</span></div>
  </div>`;
}

function sameDay(a, b) {
  return (
    a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  );
}

export function weekStrip(logs) {
  const days = [];
  for (let offset = 6; offset >= 0; offset -= 1) {
    days.push(new Date(Date.now() - offset * 86400000));
  }
  const today = new Date();
  return `<div class="week-strip">${days
    .map((day) => {
      const completed = logs.some((log) => sameDay(new Date(log.date), day));
      const isToday = sameDay(day, today);
      const classes = ["week-dot", completed ? "done" : "", isToday ? "today" : ""].filter(Boolean).join(" ");
      return `<div class="week-day"><span class="dow">${FMT.weekdayNarrow.format(day)}</span><span class="${classes}"></span></div>`;
    })
    .join("")}</div>`;
}

export function workoutPreviewRow(exercise, completedSets) {
  const done = completedSets === exercise.sets;
  return `<div class="exercise-row">
    <span class="status-icon ${done ? "done" : ""}" style="--knockout:#111">${icon(done ? "check-circle-fill" : "circle", 24)}</span>
    <span class="meta">
      <span class="t-headline">${exercise.name}</span>
      <span class="t-caption secondary">${exercise.sets} sets · ${exercise.reps} · ${exercise.load}</span>
    </span>
    <span class="t-caption secondary mono-num">${completedSets}/${exercise.sets}</span>
  </div>`;
}

function streakToolbar() {
  if (store.streak <= 0) return "";
  return `<span class="row" style="--row-gap:4px;color:#fff">
    ${icon("flame-fill", 18)}<span class="t-headline mono-num">${store.streak}</span></span>`;
}

/* ------------------------------------------------------------------ TodayView */

export function todayScreen() {
  const workout = store.recommendedWorkout;
  const offset = store.selectedDateOffset;
  const displayed = new Date(Date.now() + offset * 86400000);
  const dayLabel = offset === 0 ? "Today" : FMT.weekdayWide.format(displayed);
  const ringProgress = store.weeklySessions / Math.max(store.profile.daysPerWeek, 1);

  const daySwitcher = `<div class="row" style="--row-gap:12px">
    <button class="icon-btn" data-action="day-prev" aria-label="Previous day">${icon("chevron-left", 19)}</button>
    <div style="display:flex;flex-direction:column;gap:4px;min-width:0">
      <span class="t-title">${dayLabel}</span>
      <span class="t-caption secondary">${FMT.monthDay.format(displayed)}</span>
    </div>
    <div class="spacer"></div>
    <button class="pill-btn" data-action="day-today">Today</button>
    <button class="icon-btn" data-action="day-next" aria-label="Next day">${icon("chevron-right", 19)}</button>
  </div>`;

  const hero = card(`<div class="stack" style="--stack-gap:24px">
    <div class="row" style="--row-gap:16px;align-items:flex-start">
      <div style="display:flex;flex-direction:column;gap:8px;flex:1;min-width:0">
        <span class="t-eyebrow secondary">${workout.intensityNote.toUpperCase()}</span>
        <span class="t-display autofit" data-lines="2">${workout.title}</span>
      </div>
      ${miniProgressRing(ringProgress, String(store.weeklySessions), "sessions")}
    </div>
    <div class="row" style="--row-gap:24px">
      ${metricLabel("Time", `${workout.estimatedMinutes} min`)}
      ${metricLabel("Sets", String(store.totalSets))}
      ${metricLabel("Focus", workout.focus)}
    </div>
    <button class="primary-btn" data-action="start-session">${icon("play-fill", 16)} Start session</button>
    <button class="text-btn" style="height:44px;gap:8px" data-action="adjust-today">${icon("swap-arrows", 18)} Swap or regenerate</button>
  </div>`);

  const readiness = card(
    `<div class="row" style="--row-gap:16px">
      ${metricLabel("Volume", `${grouped(store.weeklyVolume)} kg`)}
      <span class="v-divider"></span>
      ${metricLabel("Latest RPE", store.lastLog ? `${store.lastLog.rpe}/10` : "Ready")}
    </div>`,
    "kova-card--raised"
  );

  const guidance = card(`<div class="row" style="--row-gap:16px;align-items:flex-start">
    <span class="tile">${icon("ecg", 20)}</span>
    <span style="display:flex;flex-direction:column;gap:8px;min-width:0">
      <span class="t-headline">Why this session</span>
      <span class="t-body secondary">${workout.rationale}</span>
    </span>
  </div>`);

  const trainingWeek = `<div class="stack" style="--stack-gap:16px">
    <div class="row">
      <span class="t-title">This week</span>
      <div class="spacer"></div>
      <span class="t-caption secondary mono-num">${store.weeklySessions}/${store.profile.daysPerWeek} sessions</span>
    </div>
    ${card(weekStrip(store.workoutHistory))}
  </div>`;

  return {
    source: "ios/KOVAAi/Views/TodayView.swift",
    html: `<div class="ios-screen">
      <div class="nav-bar"><div class="nav-actions">${streakToolbar()}
        <button class="icon-btn" data-action="open-settings" aria-label="Settings">${icon("gear", 20)}</button>
      </div></div>
      <div class="scroll" data-scroll="today"><div class="scroll-pad">
        <div class="stack">${daySwitcher}${hero}${readiness}${guidance}${trainingWeek}</div>
      </div></div>
    </div>`,
  };
}

/* --------------------------------------------------------------- HistoryView */

export function historyScreen() {
  const logs = [...store.workoutHistory].sort((a, b) => new Date(b.date) - new Date(a.date));

  const hero = card(`<div class="stack" style="--stack-gap:12px">
    <span class="t-eyebrow secondary">Consistency</span>
    <span class="t-display mono-num">${store.streak} days</span>
    <span class="t-body secondary">Keep your current run with one focused session today.</span>
    <div style="padding-top:12px">${weekStrip(store.workoutHistory)}</div>
  </div>`);

  const stats = `<div class="row" style="--row-gap:16px">
    ${card(metricLabel("This week", `${store.weeklySessions} sessions`))}
    ${card(metricLabel("Volume", `${Math.floor(store.weeklyVolume / 1000)}k kg`))}
  </div>`;

  const list = `<div class="stack" style="--stack-gap:16px">
    <span class="t-title">Sessions</span>
    ${logs
      .map(
        (log) => card(`<div class="row" style="--row-gap:16px">
          <span class="tile">${icon(FOCUS_SYMBOL[log.focus] || "dumbbell", 20)}</span>
          <span style="display:flex;flex-direction:column;gap:4px;min-width:0;flex:1">
            <span class="t-headline">${log.planTitle}</span>
            <span class="t-caption secondary">${FMT.weekdayMonthDay.format(new Date(log.date))}</span>
          </span>
          <span style="display:flex;flex-direction:column;gap:4px;align-items:flex-end">
            <span class="t-headline mono-num">${log.durationMinutes} min</span>
            <span class="t-caption secondary">RPE ${log.rpe}</span>
          </span>
        </div>`)
      )
      .join("")}
  </div>`;

  return {
    source: "ios/KOVAAi/Views/HistoryView.swift",
    html: `<div class="ios-screen">
      <div class="nav-bar"><div class="nav-actions">${streakToolbar()}</div></div>
      <div class="scroll" data-scroll="history">
        <div class="nav-large-title">History</div>
        <div class="scroll-pad" style="padding-top:4px"><div class="stack">${hero}${stats}${list}</div></div>
      </div>
    </div>`,
  };
}

/* ------------------------------------------------------------------ PlanView */

const PHASES = [
  ["Foundation", "Weeks 1–2", "Build repeatable form and effort"],
  ["Progression", "Weeks 3–6", "Add load or reps when feedback allows"],
  ["Consolidation", "Week 7", "Hold quality work and assess recovery"],
];

export function planScreen() {
  const workout = store.recommendedWorkout;
  const activePhaseIndex = store.weeklySessions >= store.profile.daysPerWeek ? 1 : 0;

  const hero = card(`<div class="stack" style="--stack-gap:20px">
    <span class="t-eyebrow secondary">Program</span>
    <span class="t-display autofit" data-lines="2">${store.profile.goal} block</span>
    <div class="row" style="--row-gap:24px">
      ${metricLabel("Cadence", `${store.profile.daysPerWeek}d/week`)}
      ${metricLabel("Completed", String(store.weeklySessions))}
      ${metricLabel("Volume", `${grouped(store.weeklyVolume)} kg`)}
    </div>
  </div>`);

  const phases = `<div class="stack" style="--stack-gap:16px">
    <span class="t-title">Phases</span>
    ${PHASES.map((phase, index) => {
      const done = index < activePhaseIndex;
      const active = index === activePhaseIndex;
      const badge = `<span class="tile" style="border-radius:50%;background:${active ? "#fff" : "var(--surface-raised)"};color:${active ? "#000" : "#fff"}">
        ${done ? icon("checkmark", 20, 2.2) : `<span class="t-headline">${index + 1}</span>`}</span>`;
      return card(`<div class="row" style="--row-gap:16px;align-items:flex-start">
        ${badge}
        <span style="display:flex;flex-direction:column;gap:4px;min-width:0">
          <span class="t-headline">${phase[0]}</span>
          <span class="t-caption secondary">${phase[1]}</span>
          <span class="t-body secondary" style="font-size:15px">${phase[2]}</span>
        </span>
      </div>`);
    }).join("")}
  </div>`;

  const next = `<div class="stack" style="--stack-gap:16px">
    <span class="t-title">Next</span>
    ${card(`<div class="stack" style="--stack-gap:16px">
      <div class="row" style="--row-gap:16px">
        <span style="display:flex;flex-direction:column;gap:4px;min-width:0;flex:1">
          <span class="t-headline">${workout.title}</span>
          <span class="t-body secondary" style="font-size:15px">${store.totalSets} sets · ${workout.estimatedMinutes} minutes</span>
        </span>
        <span class="tile">${icon(FOCUS_SYMBOL[workout.focus] || "dumbbell", 20)}</span>
      </div>
      ${workout.exercises.slice(0, 3).map((exercise) => workoutPreviewRow(exercise, 0)).join("")}
    </div>`)}
  </div>`;

  return {
    source: "ios/KOVAAi/Views/PlanView.swift",
    html: `<div class="ios-screen">
      <div class="nav-bar">
        <div class="nav-bar-inline-title">Plan</div>
        <div class="nav-actions">${streakToolbar()}</div>
      </div>
      <div class="scroll" data-scroll="plan"><div class="scroll-pad">
        <div class="stack">${hero}${phases}${next}</div>
      </div></div>
    </div>`,
  };
}

/* --------------------------------------------------------------- SessionView */

export function sessionScreen(session) {
  const workout = store.recommendedWorkout;

  const header = `<div class="session-header">
    <span class="t-eyebrow secondary">${workout.focus.toUpperCase()}</span>
    <span class="t-title">${workout.title}</span>
    <span class="t-body secondary">Complete a set to start its rest timer. KOVA will vibrate when recovery is done.</span>
  </div>`;

  const cards = workout.exercises
    .map((exercise) => {
      const completed = store.setsCompleted(exercise);
      const allDone = completed === exercise.sets;
      const chips = Array.from({ length: exercise.sets }, (_unused, index) => {
        const setNumber = index + 1;
        return `<span class="set-chip ${setNumber <= completed ? "done" : ""}">${setNumber}</span>`;
      }).join("");
      return card(`<div class="stack" style="--stack-gap:16px">
        <div class="row" style="--row-gap:16px;align-items:flex-start">
          <span style="display:flex;flex-direction:column;gap:4px;min-width:0;flex:1">
            <span class="t-headline">${exercise.name}</span>
            <span class="t-caption secondary">${exercise.reps} reps · ${exercise.load} · ${exercise.restSeconds}s rest</span>
          </span>
          <span class="t-headline mono-num">${completed}/${exercise.sets}</span>
        </div>
        <div class="set-chips">${chips}</div>
        <button class="soft-btn" data-action="log-set" data-exercise="${exercise.id}" ${allDone ? "disabled" : ""}>
          ${icon(allDone ? "checkmark" : "plus", 17, 2)} ${allDone ? "All sets complete" : "Log next set"}
        </button>
      </div>`);
    })
    .join("");

  const inset = session.restSecondsRemaining > 0
    ? `<div class="rest-bar">
        <span>${icon("timer", 20)}</span>
        <span class="rest-meta">
          <span class="t-caption secondary">Resting after ${session.activeRestExercise ? session.activeRestExercise.name : "set"}</span>
          <span class="rest-time" id="rest-time">${clock(session.restSecondsRemaining)}</span>
        </span>
        <div class="spacer"></div>
        <button class="text-btn" style="width:auto;min-height:44px;padding:0 6px" data-action="skip-rest">Skip</button>
      </div>`
    : session.isSessionComplete
      ? `<div style="padding:12px 20px;background:var(--background)">
          <button class="primary-btn" data-action="open-feedback">Finish &amp; adapt next workout</button>
        </div>`
      : "";

  return {
    source: "ios/KOVAAi/Views/SessionView.swift",
    html: `<div class="cover" data-cover="session">
      <div class="ios-screen">
        <div class="nav-bar">
          <button class="text-btn" style="width:auto;min-height:44px;padding:0 10px" data-action="end-session">End</button>
          <div class="nav-actions"><span class="t-headline mono-num" id="elapsed-timer">${clock(session.elapsedSeconds)}</span></div>
        </div>
        <div class="scroll" data-scroll="session"><div class="scroll-pad">
          <div class="stack">${header}<div class="stack" style="--stack-gap:16px">${cards}</div></div>
        </div></div>
        <div class="safe-inset">${inset}</div>
      </div>
    </div>`,
  };
}

/* ------------------------------------------------------------- FeedbackView */

export function feedbackSheet(feedback) {
  const picker = (title, value, values, suffix, action) => `<div class="stack" style="--stack-gap:16px">
    <span class="t-headline">${title}</span>
    <div class="score-row">
      ${values
        .map(
          (score) =>
            `<button class="score-chip ${score === value ? "selected" : ""}" data-action="${action}" data-score="${score}">${score}${suffix}</button>`
        )
        .join("")}
    </div>
  </div>`;

  return {
    source: "ios/KOVAAi/Views/SessionView.swift · FeedbackView",
    html: `<div class="layer" data-layer="feedback">
      <div class="scrim"></div>
      <div class="sheet" data-sheet="feedback">
        <div class="feedback">
          <div class="stack" style="--stack-gap:8px">
            <span class="t-title">Session review</span>
            <span class="t-body secondary">Your answers tune the next session locally.</span>
          </div>
          ${picker("How hard was it?", feedback.rpe, [6, 7, 8, 9, 10], "/10", "set-rpe")}
          ${picker("Current soreness", feedback.soreness, [1, 2, 3, 4, 5], "/5", "set-soreness")}
          <div class="spacer"></div>
          ${store.backendError ? `<span class="t-caption secondary">${store.backendError}</span>` : ""}
          <button class="primary-btn" data-action="save-feedback">Save feedback</button>
        </div>
      </div>
    </div>`,
  };
}

/* -------------------------------------------------------------- SettingsView */

function settingsRow(title, value, symbol) {
  return `<div class="settings-row">
    <span style="color:var(--secondary-text);width:44px;display:grid;place-items:center">${icon(symbol, 20)}</span>
    <span class="label">${title}</span>
    <span class="value">${value}</span>
  </div>`;
}

export function settingsSheet(settings) {
  const health = HEALTH_STATE[store.healthConnection] || HEALTH_STATE.notConnected;
  const reminderTime = hourLabel(store.profile.reminderHour);

  const account = card(`<div class="stack" style="--stack-gap:16px">
    <span class="t-title">Account</span>
    <div class="row" style="--row-gap:16px">
      <span style="width:34px;display:grid;place-items:center;--knockout:#111">${icon(store.isAuthenticated ? "person-circle-fill" : "person-circle", 30)}</span>
      <span style="display:flex;flex-direction:column;gap:4px;min-width:0">
        <span class="t-headline">${store.isAuthenticated ? "Cloud coaching active" : "Sign in required"}</span>
        <span class="t-body secondary" style="font-size:15px">${
          store.isAuthenticated
            ? "Your plan and completed sessions can sync."
            : "Sign in to save completed sessions and exports."
        }</span>
        ${store.email ? `<span class="t-caption tertiary">${store.email}</span>` : ""}
      </span>
    </div>
    ${store.isAuthenticated ? `<button class="text-btn" data-action="sign-out">Sign out</button>` : ""}
  </div>`);

  const coaching = card(`<div class="stack" style="--stack-gap:16px">
    <span class="t-title">Coaching</span>
    ${settingsRow("Goal", store.profile.goal, "target")}
    ${settingsRow("Cadence", `${store.profile.daysPerWeek} days per week`, "calendar")}
    ${settingsRow("Equipment", store.profile.equipment, "dumbbell")}
    <button class="text-btn" data-action="rebuild-profile">Rebuild coaching profile</button>
  </div>`);

  const healthCard = card(`<div class="stack" style="--stack-gap:16px">
    <span class="t-title">Apple Health</span>
    <div class="row" style="--row-gap:16px;align-items:flex-start">
      <span class="tile">${icon("heart-square", 20)}</span>
      <span style="display:flex;flex-direction:column;gap:4px;min-width:0">
        <span class="t-headline">${health.title}</span>
        <span class="t-body secondary" style="font-size:15px">${health.detail}</span>
      </span>
    </div>
    <button class="primary-btn" data-action="connect-health">${
      store.healthConnection === "connected" ? "Refresh permission" : "Connect Apple Health"
    }</button>
    <span class="t-caption secondary">Apple Health keeps read permissions private. Check Health access on your iPhone if workout context is unavailable.</span>
  </div>`);

  const reminders = card(`<div class="stack" style="--stack-gap:16px">
    <span class="t-title">Reminders</span>
    <div class="toggle-row">
      <span>Daily workout reminder</span>
      <span class="toggle ${settings.remindersOn ? "on" : ""}" data-action="toggle-reminders" role="switch" aria-checked="${settings.remindersOn}"><i></i></span>
    </div>
    <span class="t-caption secondary">${settings.reminderStatus || "Reminders are off"}</span>
  </div>`);

  const data = card(`<div class="stack" style="--stack-gap:16px">
    <span class="t-title">Data</span>
    <button class="text-btn" data-action="refresh-data">Refresh training data</button>
    <button class="text-btn" data-action="export-data">Export training summary</button>
    ${store.isSyncing ? `<span class="t-caption secondary"><span class="sync-dot"></span>Syncing training data…</span>` : ""}
    ${store.exportStatus ? `<span class="t-caption secondary">${store.exportStatus}</span>` : ""}
    ${store.backendError ? `<span class="t-caption secondary">${store.backendError}</span>` : ""}
  </div>`);

  const danger = `<div class="stack" style="--stack-gap:16px">
    <span class="t-title">Account data</span>
    <button class="text-btn destructive" data-action="ask-delete-account">Delete account</button>
  </div>`;

  return {
    source: "ios/KOVAAi/Views/SettingsView.swift",
    html: `<div class="layer" data-layer="settings">
      <div class="scrim" data-action="close-settings"></div>
      <div class="sheet" data-sheet="settings">
        <div class="nav-bar">
          <div class="nav-bar-inline-title">Settings</div>
          <div class="nav-actions">
            <button class="text-btn" style="width:auto;min-height:44px;padding:0 12px" data-action="close-settings">Done</button>
          </div>
        </div>
        <div class="scroll" data-scroll="settings"><div class="settings-stack">
          ${account}${coaching}${healthCard}${reminders}${data}${danger}
          <div class="t-caption tertiary">Reminder time: ${reminderTime} · preview build ${window.__KOVA_VERSION || "dev"}</div>
        </div></div>
      </div>
    </div>`,
  };
}

/* ------------------------------------------------------------ OnboardingView */

export function onboardingScreen(state, { animated = true } = {}) {
  const step = state.step;
  const capsules = Array.from({ length: 4 }, (_u, index) => `<i class="${index <= step ? "on" : ""}"></i>`).join("");

  const choiceRow = (label, selected, action, extra = "") =>
    `<button class="choice-row ${selected ? "selected" : ""}" style="--knockout:${selected ? "#fff" : "#1a1a1a"}" data-action="${action}" ${extra}>
      <span style="flex:1">${label}</span>${icon(selected ? "check-circle-fill" : "circle", 22)}
    </button>`;

  let content = "";
  if (step === 0) {
    content = `<div class="stack" style="--stack-gap:24px">
      <span class="t-display autofit" data-lines="2">Build a plan that adapts</span>
      <span class="t-body secondary">KOVA uses effort and soreness feedback to tune your next workout.</span>
      <div class="stack" style="--stack-gap:12px">
        ${choiceRow("Hypertrophy", state.goal === "Hypertrophy", "set-goal", `data-value="Hypertrophy"`)}
        ${choiceRow("Strength", state.goal === "Strength", "set-goal", `data-value="Strength"`)}
      </div>
    </div>`;
  } else if (step === 1) {
    content = `<div class="stack" style="--stack-gap:24px">
      <span class="t-display autofit" data-lines="2">Your weekly rhythm</span>
      <span class="t-body secondary">Choose a cadence you can keep consistently.</span>
      <div class="stack" style="--stack-gap:12px">
        ${[3, 4, 5]
          .map((days) => choiceRow(`${days} days per week`, state.daysPerWeek === days, "set-days", `data-value="${days}"`))
          .join("")}
      </div>
    </div>`;
  } else if (step === 2) {
    content = `<div class="stack" style="--stack-gap:24px">
      <span class="t-display autofit" data-lines="2">Your equipment</span>
      <span class="t-body secondary">We will only recommend movements you can actually do.</span>
      <div class="stack" style="--stack-gap:12px">
        ${["Full gym", "Dumbbells + bench", "Minimal equipment"]
          .map((item) => choiceRow(item, state.equipment === item, "set-equipment", `data-value="${item}"`))
          .join("")}
      </div>
    </div>`;
  } else {
    const hours = Array.from({ length: 16 }, (_u, index) => index + 6);
    content = `<div class="stack" style="--stack-gap:24px">
      <span class="t-display autofit" data-lines="2">Your plan is ready</span>
      <span class="t-body secondary">Set your reminder now. Your account will keep this plan and every completed session in sync.</span>
      <div class="wheel" data-wheel="reminder">
        <div class="wheel-selection"></div>
        <div class="wheel-scroll" id="reminder-wheel">
          <div class="pad"></div>
          ${hours
            .map((hour) => `<div class="wheel-item ${hour === state.reminderHour ? "selected" : ""}" data-hour="${hour}">${hourLabel(hour)}</div>`)
            .join("")}
          <div class="pad"></div>
        </div>
      </div>
    </div>`;
  }

  return {
    source: "ios/KOVAAi/Views/OnboardingView.swift",
    html: `<div class="cover ${animated ? "" : "no-anim"}" data-cover="onboarding">
      <div class="onboarding">
        <div class="progress-capsules">${capsules}</div>
        <div class="step-content">${content}</div>
        <button class="primary-btn" data-action="onboarding-continue">${step === 3 ? "Continue to account" : "Continue"}</button>
      </div>
    </div>`,
  };
}

/* --------------------------------------------------------- AuthenticationView */

export function authScreen(state, { animated = true } = {}) {
  const disabled = state.isSubmitting || !state.email || state.password.length < 8;
  return {
    source: "ios/KOVAAi/Views/AuthenticationView.swift",
    html: `<div class="cover ${animated ? "" : "no-anim"}" data-cover="auth">
      <div class="auth-screen">
        <div class="push"></div>
        <span class="t-display autofit" data-lines="2">${state.createAccount ? "Save your coaching" : "Welcome back"}</span>
        <span class="t-body secondary">${
          state.createAccount
            ? "Create an account to keep your plan, workout history, and adaptive coaching in sync."
            : "Sign in to continue with your saved coaching plan."
        }</span>
        <input class="field" id="auth-email" type="email" inputmode="email" autocapitalize="none" autocomplete="off" placeholder="Email" value="${state.email.replace(/"/g, "&quot;")}" />
        <input class="field" id="auth-password" type="password" placeholder="Password" value="${state.password.replace(/"/g, "&quot;")}" />
        ${state.errorText ? `<span class="t-caption secondary">${state.errorText}</span>` : ""}
        <button class="primary-btn" id="auth-submit" data-action="auth-submit" ${disabled ? "disabled" : ""}>
          ${state.isSubmitting ? "Working…" : state.createAccount ? "Create account" : "Sign in"}
        </button>
        <button class="link-btn" data-action="auth-toggle">${
          state.createAccount ? "I already have an account" : "Create a new account"
        }</button>
        <div class="push"></div>
      </div>
    </div>`,
  };
}

/* --------------------------------------------- dialogs & alerts (iOS chrome) */

export function adjustTodayDialog() {
  return {
    source: "ios/KOVAAi/Views/TodayView.swift · confirmationDialog",
    html: `<div class="layer" data-layer="dialog">
      <div class="scrim" data-action="close-dialog"></div>
      <div class="action-sheet">
        <div class="action-group">
          <div class="action-title"><b>Adjust today</b></div>
          <button class="action-btn" data-action="swap-focus">Swap focus</button>
          <button class="action-btn" data-action="regenerate-volume">Regenerate volume</button>
        </div>
        <div class="action-group"><button class="action-btn bold" data-action="close-dialog">Cancel</button></div>
      </div>
    </div>`,
  };
}

export function deleteAccountAlert() {
  return {
    source: "ios/KOVAAi/Views/SettingsView.swift · alert",
    html: `<div class="layer" data-layer="dialog">
      <div class="scrim" data-action="close-dialog"></div>
      <div class="alert">
        <div class="alert-body">
          <b>Delete account?</b>
          <p>This permanently removes your account and synced coaching data.</p>
        </div>
        <div class="alert-actions">
          <button data-action="close-dialog">Cancel</button>
          <button class="destructive" data-action="confirm-delete">Continue</button>
        </div>
      </div>
    </div>`,
  };
}

export function passwordAlert(value) {
  return {
    source: "ios/KOVAAi/Views/SettingsView.swift · alert(SecureField)",
    html: `<div class="layer" data-layer="dialog">
      <div class="scrim" data-action="close-dialog"></div>
      <div class="alert">
        <div class="alert-body">
          <b>Confirm password</b>
          <p>Enter your password to permanently delete this email account.</p>
          <input class="field" id="delete-password" type="password" placeholder="Password" value="${value.replace(/"/g, "&quot;")}" />
        </div>
        <div class="alert-actions">
          <button data-action="close-dialog">Cancel</button>
          <button class="destructive" data-action="delete-account">Delete account</button>
        </div>
      </div>
    </div>`,
  };
}
