/* HTTP-laag + preview-instrumentatie.
   Alle verkeer gaat met relatieve paden naar dezelfde origin, zodat de
   preview via de proxied host werkt zonder CORS of localhost-aannames. */

let getToken = () => null;
const apiListeners = [];
const deviceListeners = [];

export function setTokenProvider(fn) {
  getToken = fn;
}

export function onApiLog(fn) {
  apiListeners.push(fn);
}

export function onDeviceLog(fn) {
  deviceListeners.push(fn);
}

export function logDevice(kind, message) {
  const entry = { kind, message, at: new Date() };
  deviceListeners.forEach((fn) => fn(entry));
  return entry;
}

/* HapticService uit ios/KOVAAi/Services/NotificationService.swift */
export function haptic(kind) {
  const labels = {
    selection: "UISelectionFeedback",
    setCompleted: "UINotificationFeedback (.success)",
    restFinished: "UINotificationFeedback (.warning)",
  };
  try {
    if (navigator.vibrate) {
      navigator.vibrate(kind === "selection" ? 8 : 18);
    }
  } catch {
    /* vibrator API is optioneel */
  }
  logDevice("Haptics", `${labels[kind] || kind} → gesimuleerd`);
  const device = document.getElementById("device");
  if (device) {
    device.classList.remove("haptic");
    void device.offsetWidth;
    device.classList.add("haptic");
  }
}

export class ApiError extends Error {
  constructor(message, status, detail) {
    super(message);
    this.status = status;
    this.detail = detail;
  }
}

async function request(method, path, body, { auth = true } = {}) {
  const started = performance.now();
  const token = auth ? getToken() : null;
  const headers = { Accept: "application/json" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (token) headers.Authorization = `Bearer ${token}`;

  let response;
  let payload = null;
  let failure = null;
  try {
    response = await fetch(path, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    try {
      payload = text ? JSON.parse(text) : null;
    } catch {
      payload = text;
    }
    if (!response.ok) {
      const detail = payload && payload.detail ? payload.detail : `HTTP ${response.status}`;
      failure = new ApiError(String(detail), response.status, payload);
    }
  } catch (error) {
    failure = new ApiError(error.message || "Netwerkfout", 0, null);
  }

  const entry = {
    method,
    path,
    status: response ? response.status : 0,
    ms: Math.round(performance.now() - started),
    ok: !failure,
    error: failure ? failure.message : null,
    at: new Date(),
  };
  apiListeners.forEach((fn) => fn(entry));

  if (failure) throw failure;
  return payload;
}

export const api = {
  get: (path, options) => request("GET", path, undefined, options),
  put: (path, body, options) => request("PUT", path, body, options),
  post: (path, body, options) => request("POST", path, body, options),
};
