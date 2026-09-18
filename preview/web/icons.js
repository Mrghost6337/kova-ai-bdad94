/* SF-Symbol-achtige iconen als inline SVG (SF Symbols zelf zijn niet
   beschikbaar buiten Apple-platforms). Elke naam komt overeen met de
   systemImage die in de SwiftUI-bron gebruikt wordt. */

const S = 1.7; // standaard lijndikte

const paths = {
  // figure.strengthtraining.traditional (Coach-tab, Legs-focus)
  dumbbell: `<path d="M3.2 9.4v5.2M6.4 7.2v9.6M17.6 7.2v9.6M20.8 9.4v5.2M6.4 12h11.2"/>`,

  // figure.strengthtraining.functional (Upper-focus)
  "figure-lift": `<circle cx="12" cy="4.4" r="1.9"/><path d="M8.6 8.9 12 8l3.4.9M5.6 12.6 8.6 9.4M18.4 12.6 15.4 9.4M10.4 20.4 12 13.6l1.6 6.8"/>`,

  // clock.arrow.circlepath (History-tab)
  "clock-rotate": `<path d="M11.6 7.6v4.6l3.1 1.9"/><path d="M19.9 12.4a8 8 0 1 1-2.5-5.9"/><path d="M20.6 4.2v4.3h-4.3"/>`,

  // calendar (Plan-tab)
  calendar: `<rect x="3.4" y="5.2" width="17.2" height="15.4" rx="3.2"/><path d="M3.4 9.9h17.2M8.2 3.4v3.4M15.8 3.4v3.4"/>`,

  // flame.fill
  "flame-fill": `<path fill="currentColor" stroke="none" d="M12.6 2.6c.9 3-1.3 4.3-2.8 6a7.4 7.4 0 0 0-1.9 5.1 5.1 5.1 0 0 0 4.5 5.1c-.7-1.8.4-3.3 1.7-4.3 1.4-1.1 2.6-2.5 2.6-4.6 1.1 1.3 1.9 2.9 1.9 4.7A7.7 7.7 0 0 1 12 22a7.7 7.7 0 0 1-6.2-12.3C7.3 7.4 11.7 6.1 12.6 2.6Z"/>`,

  // gearshape
  gear: `<circle cx="12" cy="12" r="3.1"/><path d="M12 2.9v2.3M12 18.8v2.3M21.1 12h-2.3M5.2 12H2.9M18.4 5.6l-1.6 1.6M7.2 16.8l-1.6 1.6M18.4 18.4l-1.6-1.6M7.2 7.2 5.6 5.6"/>`,

  // play.fill
  "play-fill": `<path fill="currentColor" stroke="none" d="M8.4 5.1c0-.9 1-1.5 1.8-1L19 9.6c.8.5.8 1.6 0 2l-8.8 5.5c-.8.5-1.8-.1-1.8-1V5.1Z"/>`,

  // arrow.triangle.2.circlepath
  "swap-arrows": `<path d="M4.2 11.2a7.9 7.9 0 0 1 13.2-5"/><path d="M17.8 3.1v3.6h-3.6"/><path d="M19.8 12.8a7.9 7.9 0 0 1-13.2 5"/><path d="M6.2 20.9v-3.6h3.6"/>`,

  "chevron-left": `<path d="M14.6 5.4 8 12l6.6 6.6"/>`,
  "chevron-right": `<path d="M9.4 5.4 16 12l-6.6 6.6"/>`,
  "chevron-up": `<path d="M5.4 14.6 12 8l6.6 6.6"/>`,
  "chevron-down": `<path d="M5.4 9.4 12 16l6.6-6.6"/>`,

  // circle
  circle: `<circle cx="12" cy="12" r="8.6"/>`,

  // checkmark.circle.fill  (knock-out kleur via --knockout)
  "check-circle-fill": `<circle cx="12" cy="12" r="9.4" fill="currentColor" stroke="none"/><path d="M7.6 12.3 10.7 15.4l5.9-6.4" stroke="var(--knockout, #000)" stroke-width="2"/>`,

  // checkmark
  checkmark: `<path d="M5 12.6 9.7 17.2 19 6.9" stroke-width="2.1"/>`,

  // plus
  plus: `<path d="M12 5.4v13.2M5.4 12h13.2" stroke-width="2"/>`,

  // timer
  timer: `<circle cx="12" cy="13.6" r="7.4"/><path d="M12 10.2v3.7l2.5 1.6M9.3 2.9h5.4"/>`,

  // waveform.path.ecg
  ecg: `<path d="M2.4 12.6h3.3l1.9-5 2.7 10 2.4-6.6 1.6 3.3h7.3"/>`,

  // target
  target: `<circle cx="12" cy="12" r="8.6"/><circle cx="12" cy="12" r="4.6"/><circle cx="12" cy="12" r="1.2" fill="currentColor" stroke="none"/>`,

  // heart.text.square
  "heart-square": `<rect x="3.2" y="4.6" width="17.6" height="15.2" rx="3.4"/><path d="M12 16.1s-3.4-2-3.4-4.2a1.9 1.9 0 0 1 3.4-1.1 1.9 1.9 0 0 1 3.4 1.1c0 2.2-3.4 4.2-3.4 4.2Z"/>`,

  // person.crop.circle.fill
  "person-circle-fill": `<circle cx="12" cy="12" r="9.4" fill="currentColor" stroke="none"/><circle cx="12" cy="9.6" r="2.7" fill="var(--knockout, #000)" stroke="none"/><path d="M6.6 18.3a5.6 5.6 0 0 1 10.8 0Z" fill="var(--knockout, #000)" stroke="none"/>`,

  // person.crop.circle
  "person-circle": `<circle cx="12" cy="12" r="9"/><circle cx="12" cy="9.8" r="2.6"/><path d="M6.9 18.2a5.4 5.4 0 0 1 10.2 0"/>`,

  // arrow.up.forward (Push)
  "arrow-up-forward": `<path d="M7 17 17 7M9.2 7H17v7.8"/>`,

  // arrow.down.back (Pull)
  "arrow-down-back": `<path d="M17 7 7 17M14.8 17H7V9.2"/>`,

  // square.and.arrow.up (export)
  export: `<path d="M12 15.4V4.2M8.1 7.9 12 4l3.9 3.9"/><path d="M5 13.4v5.2a1.8 1.8 0 0 0 1.8 1.8h10.4a1.8 1.8 0 0 0 1.8-1.8v-5.2"/>`,

  // arrow.clockwise (refresh)
  refresh: `<path d="M19.8 12a7.8 7.8 0 1 1-2.4-5.6"/><path d="M20.4 3.8v4.4H16"/>`,

  // bell.badge (reminders)
  bell: `<path d="M6.4 16.6V11a5.6 5.6 0 0 1 11.2 0v5.6l1.4 2H5l1.4-2Z"/><path d="M10 20.4a2.2 2.2 0 0 0 4 0"/>`,

  // trash (delete account)
  trash: `<path d="M4.8 7.4h14.4M9.4 7.4V5.2h5.2v2.2M6.6 7.4l.9 12a1.6 1.6 0 0 0 1.6 1.5h5.8a1.6 1.6 0 0 0 1.6-1.5l.9-12"/>`,

  // rectangle.and.arrow.out (sign out)
  signout: `<path d="M14.6 4.6H6.4A1.8 1.8 0 0 0 4.6 6.4v11.2a1.8 1.8 0 0 0 1.8 1.8h8.2"/><path d="M11.4 12h8.2M16.8 8.9 19.9 12l-3.1 3.1"/>`,

  // iphone (device simulation)
  iphone: `<rect x="7" y="2.6" width="10" height="18.8" rx="2.6"/><path d="M10.8 5.2h2.4"/>`,

  // statusbar
  cellular: `<path fill="currentColor" stroke="none" d="M2 15.4h2.6v3.2H2zM7 12.6h2.6V18.6H7zM12 9.4h2.6v9.2H12zM17 6h2.6v12.6H17z"/>`,
  wifi: `<path d="M2.6 8.9a13.4 13.4 0 0 1 18.8 0M6.1 12.5a8.4 8.4 0 0 1 11.8 0M9.6 16.1a3.5 3.5 0 0 1 4.8 0"/><circle cx="12" cy="19.2" r="1.1" fill="currentColor" stroke="none"/>`,
  battery: `<rect x="1.6" y="7.2" width="17.4" height="9.6" rx="3"/><path fill="currentColor" stroke="none" d="M3.4 9h11.2v6H3.4z" opacity=".95"/><path d="M21 10.4v3.2" stroke-width="2.2"/>`,

  // lock (password field)
  lock: `<rect x="4.8" y="10.4" width="14.4" height="10" rx="2.8"/><path d="M8.4 10.4V7.8a3.6 3.6 0 0 1 7.2 0v2.6"/>`,

  // sparkles (onboarding)
  sparkles: `<path d="M12 3.4 13.7 8l4.6 1.7-4.6 1.7L12 16l-1.7-4.6L5.7 9.7 10.3 8 12 3.4Z"/><path d="M18.4 15.2l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8.8-2Z"/>`,
};

export function icon(name, size = 24, strokeWidth = S) {
  const body = paths[name];
  if (!body) return "";
  return `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="${strokeWidth}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;
}

export const iconNames = Object.keys(paths);
