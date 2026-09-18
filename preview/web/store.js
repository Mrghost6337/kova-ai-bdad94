/* Port van ios/KOVAAi/Services/WorkoutStore.swift (+ Models/WorkoutModels.swift).
   Dezelfde statuslogica: lokale UserDefaults-mirror, seeded history, adaptive
   rotatie en synchronisatie met /api/v1. */

import { api, haptic, logDevice, setTokenProvider } from "./api.js";

const STORAGE_KEY = "kova.workout.store.v1";
const ONBOARDING_KEY = "kova.hasCompletedOnboarding";
const TOKEN_KEY = "kova.preview.token";

export const FOCUS_ORDER = ["Push", "Pull", "Legs", "Upper"];
export const FOCUS_SYMBOL = {
  Push: "arrow-up-forward",
  Pull: "arrow-down-back",
  Legs: "dumbbell",
  Upper: "figure-lift",
};

/* Zelfde voorschriften als WorkoutStore.makeWorkout / backend WORKOUTS */
const PRESCRIPTIONS = {
  Push: [
    { name: "Barbell bench press", sets: 4, reps: "6–8", load: "80 kg", restSeconds: 120 },
    { name: "Incline dumbbell press", sets: 3, reps: "8–10", load: "30 kg", restSeconds: 90 },
    { name: "Cable lateral raise", sets: 3, reps: "12–15", load: "12.5 kg", restSeconds: 60 },
    { name: "Rope pressdown", sets: 3, reps: "10–12", load: "32.5 kg", restSeconds: 60 },
  ],
  Pull: [
    { name: "Weighted pull-up", sets: 4, reps: "6–8", load: "+15 kg", restSeconds: 120 },
    { name: "Chest-supported row", sets: 3, reps: "8–10", load: "60 kg", restSeconds: 90 },
    { name: "Lat pulldown", sets: 3, reps: "10–12", load: "64 kg", restSeconds: 75 },
    { name: "Incline curl", sets: 3, reps: "10–12", load: "16 kg", restSeconds: 60 },
  ],
  Legs: [
    { name: "High-bar squat", sets: 4, reps: "5–7", load: "105 kg", restSeconds: 150 },
    { name: "Romanian deadlift", sets: 3, reps: "8–10", load: "90 kg", restSeconds: 120 },
    { name: "Leg press", sets: 3, reps: "10–12", load: "180 kg", restSeconds: 90 },
    { name: "Seated leg curl", sets: 3, reps: "10–12", load: "55 kg", restSeconds: 75 },
  ],
  Upper: [
    { name: "Dumbbell bench press", sets: 3, reps: "8–10", load: "34 kg", restSeconds: 90 },
    { name: "Neutral-grip pulldown", sets: 3, reps: "8–10", load: "68 kg", restSeconds: 90 },
    { name: "Machine shoulder press", sets: 3, reps: "10–12", load: "50 kg", restSeconds: 75 },
    { name: "Cable curl", sets: 2, reps: "12–15", load: "25 kg", restSeconds: 60 },
  ],
};

/* WorkoutStore.seededHistory */
const SEEDED_SESSIONS = [
  [0, "Pull", "Pull performance", 62, 15480, 8, 3],
  [1, "Legs", "Legs performance", 68, 18920, 8, 4],
  [2, "Push", "Push performance", 59, 14760, 7, 2],
  [4, "Upper", "Upper performance", 54, 12980, 7, 3],
  [5, "Legs", "Legs performance", 65, 18210, 8, 4],
  [6, "Pull", "Pull performance", 57, 13860, 7, 2],
];

export function uuid() {
  if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

function titleCase(value) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

export function makeWorkout(focus, minutes, intensity, rationale) {
  return {
    id: uuid(),
    title: `${focus} performance`,
    focus,
    estimatedMinutes: minutes,
    intensityNote: intensity,
    exercises: PRESCRIPTIONS[focus].map((exercise) => ({ id: uuid(), ...exercise })),
    rationale,
    scheduledDate: new Date().toISOString(),
  };
}

function seededHistory() {
  return SEEDED_SESSIONS.map(([offset, focus, planTitle, durationMinutes, volume, rpe, soreness]) => ({
    id: uuid(),
    planTitle,
    focus,
    date: new Date(Date.now() - offset * 86400000).toISOString(),
    durationMinutes,
    volume,
    rpe,
    soreness,
    completion: 1,
  }));
}

function planFromRemote(remote) {
  const focus = titleCase(remote.focus);
  return {
    id: remote.id,
    title: remote.title,
    focus,
    estimatedMinutes: remote.estimated_minutes,
    intensityNote: remote.intensity_note,
    exercises: (remote.exercises || []).map((exercise) => ({
      id: uuid(),
      name: exercise.name,
      sets: exercise.sets,
      reps: exercise.reps,
      load: exercise.load,
      restSeconds: exercise.rest_seconds,
    })),
    rationale: remote.rationale,
    scheduledDate: remote.created_at,
  };
}

function logFromRemote(remote) {
  return {
    id: remote.id,
    planTitle: remote.plan_title,
    focus: titleCase(remote.focus),
    date: remote.completed_at,
    durationMinutes: remote.duration_minutes,
    volume: remote.volume_kg,
    rpe: remote.rpe,
    soreness: remote.soreness,
    completion: remote.completed_sets / Math.max(remote.prescribed_sets, 1),
  };
}

function loadSavedState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export const store = {
  /* --- @Observable state --- */
  profile: { goal: "Hypertrophy", daysPerWeek: 4, equipment: "Full gym", reminderHour: 18, reminderMinute: 0 },
  recommendedWorkout: makeWorkout("Push", 58, "Progression day", "Your first progression session is ready."),
  workoutHistory: seededHistory(),
  completedSets: [],
  selectedDateOffset: 0,
  isAuthenticated: false,
  isSyncing: false,
  backendError: null,
  exportStatus: null,
  healthConnection: "notConnected",

  /* --- preview-only state --- */
  token: localStorage.getItem(TOKEN_KEY) || null,
  email: null,
  hasCompletedOnboarding: localStorage.getItem(ONBOARDING_KEY) === "true",
  listeners: [],

  init() {
    setTokenProvider(() => store.token);
    const saved = loadSavedState();
    if (saved) {
      store.profile = saved.profile;
      store.recommendedWorkout = saved.recommendedWorkout;
      store.workoutHistory = saved.workoutHistory && saved.workoutHistory.length ? saved.workoutHistory : seededHistory();
      store.persist();
    } else {
      store.profile = { goal: "Hypertrophy", daysPerWeek: 4, equipment: "Full gym", reminderHour: 18, reminderMinute: 0 };
      store.recommendedWorkout = makeWorkout("Push", 58, "Progression day", "Your first progression session is ready.");
      store.workoutHistory = seededHistory();
      store.persist();
    }
  },

  subscribe(fn) {
    store.listeners.push(fn);
  },

  notify(reason = "state") {
    store.listeners.forEach((fn) => fn(reason));
  },

  /* --- computed (Swift computed vars) --- */
  get streak() {
    const days = new Set(store.workoutHistory.map((log) => startOfDay(new Date(log.date))));
    let count = 0;
    let cursor = startOfDay(new Date());
    while (days.has(cursor)) {
      count += 1;
      cursor -= 86400000;
    }
    return count;
  },

  get weeklySessions() {
    const start = Date.now() - 6 * 86400000;
    return store.workoutHistory.filter((log) => new Date(log.date).getTime() >= start).length;
  },

  get weeklyVolume() {
    const start = Date.now() - 6 * 86400000;
    return store.workoutHistory
      .filter((log) => new Date(log.date).getTime() >= start)
      .reduce((total, log) => total + log.volume, 0);
  },

  get lastLog() {
    return [...store.workoutHistory].sort((a, b) => new Date(b.date) - new Date(a.date))[0] || null;
  },

  get totalSets() {
    return store.recommendedWorkout.exercises.reduce((total, exercise) => total + exercise.sets, 0);
  },

  /* --- persistence (UserDefaults) --- */
  persist() {
    const data = {
      profile: store.profile,
      recommendedWorkout: store.recommendedWorkout,
      workoutHistory: store.workoutHistory,
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    logDevice("UserDefaults", `${STORAGE_KEY} bijgewerkt (${store.workoutHistory.length} logs)`);
  },

  setToken(token) {
    store.token = token;
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
  },

  setOnboardingDone(done) {
    store.hasCompletedOnboarding = done;
    localStorage.setItem(ONBOARDING_KEY, done ? "true" : "false");
    logDevice("AppStorage", `${ONBOARDING_KEY} = ${done}`);
  },

  /* --- session lifecycle --- */
  async restoreSession() {
    if (!store.token) {
      store.isAuthenticated = false;
      return;
    }
    try {
      const session = await api.get("/preview/auth/session", { auth: true });
      store.isAuthenticated = Boolean(session.authenticated);
      store.email = session.user ? session.user.email : null;
      if (!store.isAuthenticated) store.setToken(null);
    } catch {
      store.isAuthenticated = false;
      store.setToken(null);
    }
    if (store.isAuthenticated) await store.refreshRemoteState();
    store.notify("restore");
  },

  async signIn(email, password, createAccount) {
    const path = createAccount ? "/preview/auth/signup" : "/preview/auth/signin";
    const result = await api.post(path, { email, password }, { auth: false });
    store.setToken(result.token);
    store.email = result.user.email;
    store.isAuthenticated = true;
    logDevice("TenxSession", `${createAccount ? "signUp" : "signIn"} → iosTokenBridge token ontvangen`);
    await store.refreshRemoteState();
  },

  async signOut() {
    try {
      await api.post("/preview/auth/signout", {});
    } catch {
      /* token was al verlopen */
    }
    store.setToken(null);
    store.isAuthenticated = false;
    store.email = null;
    store.backendError = null;
    logDevice("TenxSession", "signOut");
    store.notify("signout");
  },

  async deleteAccount(password) {
    try {
      await api.post("/preview/auth/delete", { password });
      store.setToken(null);
      store.isAuthenticated = false;
      store.backendError = null;
      store.exportStatus = "Account deleted.";
      logDevice("TenxSession", "deleteAccount → data verwijderd");
    } catch (error) {
      store.backendError = error.message;
    }
    store.notify("delete");
  },

  async refreshRemoteState() {
    if (!store.isAuthenticated) return;
    store.isSyncing = true;
    store.notify("sync");
    try {
      const [plan, history, profileResponse] = await Promise.all([
        api.get("/api/v1/active-plan"),
        api.get("/api/v1/workout-history"),
        api.get("/api/v1/coaching-profile"),
      ]);
      store.recommendedWorkout = planFromRemote(plan);
      store.workoutHistory = history.items.map(logFromRemote);
      const remoteProfile = profileResponse.items && profileResponse.items[0];
      if (remoteProfile) {
        store.profile = {
          goal: remoteProfile.goal === "strength" ? "Strength" : "Hypertrophy",
          daysPerWeek: remoteProfile.days_per_week,
          equipment: remoteProfile.equipment,
          reminderHour: remoteProfile.reminder_hour ?? store.profile.reminderHour,
          reminderMinute: remoteProfile.reminder_minute ?? store.profile.reminderMinute,
        };
      }
      store.persist();
      store.backendError = null;
    } catch (error) {
      store.backendError = error.message;
    }
    store.isSyncing = false;
    store.notify("refresh");
  },

  async syncProfile() {
    if (!store.isAuthenticated) return;
    try {
      await api.put("/api/v1/profile", {
        goal: store.profile.goal.toLowerCase(),
        days_per_week: store.profile.daysPerWeek,
        equipment: store.profile.equipment,
      });
      const confirmed = await api.get("/api/v1/coaching-profile");
      const remote = confirmed.items && confirmed.items[0];
      if (remote) {
        store.profile = {
          goal: remote.goal === "strength" ? "Strength" : "Hypertrophy",
          daysPerWeek: remote.days_per_week,
          equipment: remote.equipment,
          reminderHour: store.profile.reminderHour,
          reminderMinute: store.profile.reminderMinute,
        };
        store.persist();
      }
      store.backendError = null;
    } catch (error) {
      store.backendError = error.message;
    }
    store.notify("profile");
  },

  updateProfile({ goal, days, equipment, hour, minute }) {
    store.profile = { goal, daysPerWeek: days, equipment, reminderHour: hour, reminderMinute: minute };
    store.persist();
    if (store.isAuthenticated) {
      store.syncProfile();
      api.put("/api/v1/reminder", { reminder_hour: hour, reminder_minute: minute }).catch(() => {});
    }
    store.notify("profile");
  },

  /* --- active session --- */
  setsCompleted(exercise) {
    return store.completedSets.filter((set) => set.exerciseId === exercise.id).length;
  },

  markSetComplete(exercise) {
    const completed = store.setsCompleted(exercise);
    if (completed >= exercise.sets) return;
    store.completedSets.push({ id: uuid(), exerciseId: exercise.id, setNumber: completed + 1 });
    haptic("setCompleted");
    store.notify("set");
  },

  resetActiveSession() {
    store.completedSets = [];
    store.notify("session-reset");
  },

  async finishWorkout({ rpe, soreness, elapsedMinutes }) {
    const completion = store.completedSets.length / Math.max(store.totalSets, 1);
    const volume = store.recommendedWorkout.exercises.reduce((total, exercise) => total + exercise.sets * 850, 0);
    const log = {
      id: uuid(),
      planTitle: store.recommendedWorkout.title,
      focus: store.recommendedWorkout.focus,
      date: new Date().toISOString(),
      durationMinutes: Math.max(elapsedMinutes, 1),
      volume,
      rpe,
      soreness,
      completion,
    };

    if (!store.isAuthenticated) {
      store.backendError = "Sign in to save a completed workout.";
      store.notify("finish-blocked");
      return false;
    }

    try {
      const response = await api.post("/api/v1/workout-completions", {
        plan_id: store.recommendedWorkout.id,
        duration_minutes: log.durationMinutes,
        volume_kg: volume,
        rpe,
        soreness,
        completed_sets: Math.max(store.completedSets.length, 1),
      });
      store.workoutHistory.push(log);
      store.recommendedWorkout = planFromRemote(response.next_plan);
      store.completedSets = [];
      store.persist();
      store.backendError = null;
      logDevice("Adaptive coach", `volgende focus: ${store.recommendedWorkout.focus} (${store.recommendedWorkout.estimatedMinutes} min)`);
      store.notify("finish");
      return true;
    } catch (error) {
      store.backendError = error.message;
      store.notify("finish-error");
      return false;
    }
  },

  swapRecommendation() {
    const currentIndex = FOCUS_ORDER.indexOf(store.recommendedWorkout.focus);
    if (currentIndex < 0) return;
    const nextFocus = FOCUS_ORDER[(currentIndex + 1) % FOCUS_ORDER.length];
    store.recommendedWorkout = makeWorkout(
      nextFocus,
      store.recommendedWorkout.estimatedMinutes,
      store.recommendedWorkout.intensityNote,
      `A fresh ${nextFocus.toLowerCase()} session keeps today aligned with your training block.`
    );
    store.commitPlanAdjustment();
    store.persist();
    haptic("selection");
    store.notify("swap");
  },

  regenerateRecommendation() {
    const adjustedMinutes = Math.max(store.recommendedWorkout.estimatedMinutes - 8, 40);
    store.recommendedWorkout = makeWorkout(
      store.recommendedWorkout.focus,
      adjustedMinutes,
      "Refined volume",
      `Volume has been tightened for a focused ${adjustedMinutes}-minute session.`
    );
    store.commitPlanAdjustment();
    store.persist();
    haptic("selection");
    store.notify("regenerate");
  },

  /* Preview-extensie: in de Swift-app blijft een swap/regenerate lokaal, waardoor
     het plan-id dat later naar /workout-completions gaat niet bestaat op de server
     (HTTP 404). Hier wordt dezelfde aanpassing ook naar de backend geschreven. */
  commitPlanAdjustment() {
    if (!store.isAuthenticated) return;
    const workout = store.recommendedWorkout;
    api
      .put("/api/v1/active-plan", {
        focus: workout.focus.toLowerCase(),
        estimated_minutes: workout.estimatedMinutes,
        intensity_note: workout.intensityNote,
        rationale: workout.rationale,
      })
      .then((remote) => {
        store.recommendedWorkout = { ...planFromRemote(remote), id: remote.id };
        store.persist();
        logDevice("Preview", `plan-aanpassing gesynchroniseerd → ${remote.focus} (${remote.id.slice(0, 8)})`);
        store.notify("plan-adjusted");
      })
      .catch((error) => {
        store.backendError = error.message;
        store.notify("plan-adjust-failed");
      });
  },

  /* --- device capabilities (gesimuleerd) --- */
  async connectAppleHealth() {
    store.healthConnection = "requesting";
    store.notify("health");
    await sleep(900);
    store.healthConnection = "connected";
    logDevice("HealthKit", "requestAuthorization(read: workout, exerciseTime, activeEnergy) → gesimuleerd .connected");
    store.notify("health");
  },

  async exportTrainingSummary() {
    if (!store.isAuthenticated) {
      store.exportStatus = "Sign in to export your training summary.";
      store.notify("export");
      return;
    }
    try {
      const result = await api.post("/api/v1/storage/exports", {
        profile: store.profile,
        workouts: store.workoutHistory,
      });
      store.exportStatus = result.objects.includes(result.id)
        ? "Training summary exported."
        : "Export needs confirmation.";
      logDevice("TenxStorage", `bucket workout-exports → ${result.filename}`);
    } catch (error) {
      store.exportStatus = error.message;
    }
    store.notify("export");
  },
};

export const HEALTH_STATE = {
  unavailable: { title: "Unavailable on this device", detail: "Apple Health is available on iPhone." },
  notConnected: {
    title: "Not connected",
    detail: "Use recovery and activity context to refine coaching.",
  },
  requesting: { title: "Requesting access", detail: "Waiting for Apple Health permission." },
  connected: { title: "Connected", detail: "KOVA can use permitted activity and workout context." },
};

export function startOfDay(date) {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy.getTime();
}

export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

store.init();
