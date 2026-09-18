# KOVA Ai — live preview

Een interactieve preview van de iOS-app die in de browser draait. Een echte
iOS-simulator is hier niet mogelijk (de sandbox is Linux, zonder Xcode of een
iOS-SDK), dus deze preview rendert de SwiftUI-schermen zelf: dezelfde layout,
dezelfde design-tokens, dezelfde flows en dezelfde backend-contracten.

## Starten

```bash
python3 -m venv preview/.venv                 # eenmalig
preview/.venv/bin/pip install fastapi "uvicorn[standard]"
preview/.venv/bin/python preview/server.py    # http://0.0.0.0:8080
```

De server serveert zowel de web-UI als de API op één poort, dus de preview werkt
achter een proxy zonder CORS- of localhost-aanpassingen. Wijzig je iets in
`preview/web`, dan herlaadt de pagina automatisch (polling op `/preview/version`).

## Wat echt is en wat gesimuleerd wordt

| Onderdeel | Status |
|-----------|--------|
| Schermen, tokens, layout | 1:1 port van `ios/KOVAAi/Views` + `Components/Primitives/ClinicalTokens.swift` |
| Trainingslogica (voorschriften, push→pull→legs→upper rotatie, recovery-regel) | **echt**: geïmporteerd uit `backend/app/routes/training.py` (`WORKOUTS`, `NEXT_FOCUS`) |
| Request/response-validatie | **echt**: `backend/app/schemas.py` (Pydantic), inclusief 422-gedrag |
| API-routes | dezelfde paden en methoden als in `tenx.yaml`: `/api/v1/active-plan`, `/profile`, `/workout-completions`, `/workout-history`, `/progress-summary` |
| Database | SQLite-mirror van `services/db/migrations/001_kova_training.sql` (Postgres/Neon is hier niet beschikbaar); scoped op `owner_id` zoals de RLS-policies doen |
| Auth (email + wachtwoord, token bridge) | nagebouwd op `/preview/auth/*`, in plaats van 10x managed better-auth |
| HealthKit, notificaties, haptics | gesimuleerd; elke gebeurtenis verschijnt in het device-logboek van het paneel |
| Storage-export (`workout-exports`) | nagebouwd: JSON bestanden in `preview/.data/workout-exports` |

## Mappen

```
preview/
  server.py          FastAPI: static files + /api/v1 + /preview/*
  store.py           SQLite-laag (schema mirror van services/db/migrations)
  backend_bridge.py  importeert de echte backend-modules met stubs voor
                     app.database (psycopg/Neon) en app.tenx_auth (generated)
  web/index.html     preview-chrome + iPhone-frame
  web/styles.css     design-tokens uit ClinicalTokens.swift + iOS-chrome
  web/icons.js       SF-Symbol-benaderingen als inline SVG
  web/store.js       port van WorkoutStore.swift (+ WorkoutModels.swift)
  web/screens.js     port van de views (Today/History/Plan/Session/Onboarding/Auth/Settings)
  web/app.js         port van CoachRootView + tabs, covers, sheets, dialogs, timers
```

`.venv/` en `.data/` staan in `preview/.gitignore`.

## Verschillen met de Swift-app (bewust)

1. **`MiniProgressRing`** wordt op 96 pt gerenderd (de maat uit
   `WorkoutComponents.swift`). `TodayView.swift` zet er een extra
   `.frame(width: 48, height: 48)` op, wat in SwiftUI het binnenste 96 pt-frame
   niet verkleint maar laat overlopen; 48 pt is bovendien te klein voor de
   waarde + het label.
2. **Plan-aanpassing** (`Swap focus` / `Regenerate volume`) wordt in de preview
   ook naar de server geschreven via `PUT /api/v1/active-plan`. Zie
   "Gevonden issue" hieronder.
3. **`kerning`** van de eyebrow-tekst is als `letter-spacing: 0.09em`
   geïnterpreteerd; `KOVATokens.xxs` (4 pt) als tracking op een 12 pt caption
   zou in SwiftUI extreem breed uitpakken.

## Gevonden issue in de app (niet aangepast in `ios/`)

`WorkoutStore.swapRecommendation()` en `regenerateRecommendation()` bouwen een
nieuw `WorkoutPlan` met een vers `UUID`, maar vertellen dat niet aan de backend.
`finishWorkout(rpe:soreness:elapsedMinutes:)` stuurt vervolgens
`plan_id: recommendedWorkout.id` naar `POST /api/v1/workout-completions`, waar
`active_plan_for` dat id niet kent → **HTTP 404 "Active workout plan was not
found"**. De sessie blijft dan hangen in de feedback-sheet met een foutmelding.

Reproduceerbaar in de preview: Today → *Swap or regenerate* → *Swap focus* →
*Start session* → alle sets loggen → *Finish & adapt next workout*. Zonder de
preview-extensie (`PUT /api/v1/active-plan`) zie je de 404 in het API-logboek.

Mogelijke fixes in de Swift-app: het actieve plan-id behouden bij een swap (alleen
focus/minutes/rationale lokaal wijzigen), of een backend-route toevoegen die een
swap/regenerate persisteert.

## Rooktest

De volledige flow (onboarding → account → tabs → swap → settings → sessie →
feedback → history → uitloggen → opnieuw inloggen → account verwijderen) is
geautomatiseerd getest met jsdom + esbuild tegen de draaiende server: 48/48
checks. Het testscript leeft buiten de repo (`/tmp/kova-smoke.mjs`) zodat er
geen test-afhankelijkheden in de repo komen.
