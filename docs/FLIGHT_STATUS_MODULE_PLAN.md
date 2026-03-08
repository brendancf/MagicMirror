# MMM-FlightStatus: Full Plan (Calendar-Driven, No Manual Flight Config)

## 1. Goal

- **No manual flight list.** Flights are discovered automatically from your existing Google Calendar events.
- **Reuse existing Google auth.** Use the same OAuth credentials and token as MMM-GoogleCalendar so you don’t sign in again.
- **Show a mirror section only when there’s a flight that day**, with live status (scheduled → departed → in flight → landed) and key times (departure/arrival, delays, gate).

---

## 2. High-Level Flow

1. **Startup:** Module loads; node_helper reads the same `credentials.json` and `token.json` as MMM-GoogleCalendar (from a configurable path).
2. **Calendar fetch:** Node_helper calls Google Calendar API for the same set of calendar IDs you use in MMM-GoogleCalendar, for “today” (and optionally tomorrow) events.
3. **Flight detection:** For each event, run heuristics on title, description, and location to see if it’s a flight and extract flight number + date.
4. **Flight status:** For each detected flight, call a flight-status API (e.g. AviationStack) with flight identifier + date; cache and refresh on an interval.
5. **UI:** Frontend receives a list of “flights with status”; it only shows the section when that list is non-empty, and displays status and times.

---

## 3. Reusing MMM-GoogleCalendar Auth

### 3.1 How MMM-GoogleCalendar stores auth

- **Path:** All paths are relative to the module directory (`this.path` in the node_helper), i.e. `MagicMirror/modules/MMM-GoogleCalendar/`.
- **Files:**
  - `credentials.json` – OAuth “Desktop app” client (contains `installed.client_id`, `installed.client_secret`, `installed.redirect_uris`).
  - `token.json` – Token object written by `oauth2Client.getToken()`: `{ access_token, refresh_token, scope, ... }` (used with `setCredentials()`).
- **Scope:** `https://www.googleapis.com/auth/calendar.readonly` (enough for our use).
- **Library:** `googleapis` (`google.auth.OAuth2` + `google.calendar({ version: 'v3', auth })`).

### 3.2 How MMM-FlightStatus reuses it

- **Config option:** e.g. `googleCalendarAuthPath: "MMM-GoogleCalendar"` (module name) or an absolute path. Resolve to directory:  
  `path.join(global.rootPath || require('path').resolve(__dirname, '../..'), 'modules', config.googleCalendarAuthPath)`  
  so it points to `modules/MMM-GoogleCalendar/`.
- **Load credentials and token:** In node_helper startup (or before first calendar fetch), read:
  - `credentials.json` → parse, use `credentials.installed` (same as MMM-GoogleCalendar).
  - `token.json` → parse, pass to `oauth2Client.setCredentials(token)`.
- **Create client:** Same as MMM-GoogleCalendar: `new google.auth.OAuth2(client_id, client_secret, redirect_uri)` then `setCredentials(token)`. Do **not** write `token.json` from this module; let MMM-GoogleCalendar own token refresh. If our in-memory client’s token expires, the library will refresh using `refresh_token`; if the other module wrote a newer `token.json`, we can optionally re-read it on next fetch to stay in sync (or rely on refresh and accept possible duplicate refresh).
- **Fallback:** If `googleCalendarAuthPath` is not set or files are missing, log a clear error and do not start calendar fetching (flight section won’t appear).

---

## 4. Which Calendars to Use

- **Option A (recommended):** Config says “use same calendars as MMM-GoogleCalendar”. Implement by:
  - **Config key:** e.g. `useCalendarsFrom: 'MMM-GoogleCalendar'`.
  - **Implementation:** In node_helper, read MagicMirror config from `config/config.js` (path: `path.join(rootPath, 'config', 'config.js')`). Parse or `require()` it (if safe), find the module entry with `module: 'MMM-GoogleCalendar'`, then read `config.calendars` (or `config.config.calendars`) and extract `calendarID` for each. Use that list for `calendarId` in `calendar.events.list()`.
- **Option B:** Explicit list in our config: `calendarIds: ['id1@group.calendar.google.com', '...']`. User copies from MMM-GoogleCalendar config. Document: “Use the same calendar IDs as in MMM-GoogleCalendar.”
- **Hybrid:** If `useCalendarsFrom` is set, resolve from config; else use `calendarIds` if provided. So one source of truth (MMM-GoogleCalendar config) with override possible.

---

## 5. Fetching Calendar Events

- **API:** `calendar.events.list()` (same as MMM-GoogleCalendar).
- **Parameters:**
  - `calendarId`: from step 4.
  - `timeMin`: start of today (local or UTC, be consistent with server timezone).
  - `timeMax`: end of today (or end of tomorrow if we want “tomorrow’s flights”).
  - `singleEvents: true`, `orderBy: 'startTime'`, `maxResults` (e.g. 50–100 per calendar).
- **Range:** “Today” in the server’s timezone (or configurable timezone, e.g. `America/Los_Angeles`). Optionally include tomorrow to show flights that depart tomorrow.
- **Frequency:** e.g. every 10–15 minutes (same order as MMM-GoogleCalendar refresh). No need to be more frequent.

---

## 6. Flight Detection Heuristics

For each event we have: `summary`, `description`, `location`, `start` (dateTime or date), `end`.

### 6.1 When to treat an event as a flight

Treat as flight if **any** of:

1. **Flight number in title or description**  
   - Pattern: IATA airline code (2 letters) + optional space/dash + 1–4 digits, e.g. `WN 1234`, `AA1234`, `UA 567`.  
   - Regex suggestion: `/\b([A-Z]{2})\s*[-]?\s*(\d{2,4})\b/i` → capture airline + number, form `flightIata = airline + number` (e.g. `WN1234`).
2. **Airport codes in title, description, or location**  
   - Pattern: 3-letter IATA code (e.g. BWI, SEA, JFK).  
   - Use a fixed set of known airport codes (or a small list of ~hundreds) to avoid false positives on random 3-letter words. If we find two different airport codes (e.g. BWI and SEA), treat as flight-like; optionally require also a flight number or “flight” keyword.
3. **Keyword in title**  
   - Title (or description) contains “flight” (and optionally a number or airport code).  
   - e.g. “Flight to Seattle”, “Ellie’s flight home” → if we also find a flight number or two airport codes, classify as flight.

### 6.2 Extracting flight identifier and date

- **Flight IATA:** From regex: `airline + number`, e.g. `WN1234`. Normalize to no space (e.g. `WN1234`) for the status API.
- **Date:** Use event’s **start** date (dateTime or date). Format as `YYYY-MM-DD` for the API. For all-day events, use that date; for timed events, use the local date of start.
- **Label (optional):** Use event `summary` (e.g. “Ellie – Baltimore to Seattle”) or build from “Flight WN1234” for display.

### 6.3 Ambiguity and duplicates

- If an event has multiple flight-number matches (e.g. “AA100 and AA200”), take the first or all and create one “flight” record per (flightIata, date). Dedupe by (flightIata, date) across events.
- If we find airport codes but no flight number, we **cannot** call a flight API by number; skip or show “Flight (from calendar)” without live status unless we add a different API (e.g. by route/date). So **require at least one extractable flight number** for live status.

---

## 7. Flight Status API (AviationStack)

- **Endpoint:** `GET https://api.aviationstack.com/v1/flights`
- **Parameters:** `access_key`, `flight_iata` (e.g. `WN1234`), `flight_date` (e.g. `2025-03-08`).
- **Response:** `data[]` with `flight_status` (`scheduled` | `active` | `landed` | `cancelled` | `incident` | `diverted`), `departure` / `arrival` (each with `scheduled`, `actual`, `delay`, `gate`, `iata`, etc.).
- **Rate limit:** Free tier 100 requests/month. Only request when we have at least one flight that day; poll e.g. every 15–20 minutes per flight. For 1–2 flights, ~50–100 requests/day → need to stay under 100/month (e.g. poll every 30 min, or only on days with flights and cap requests).
- **Config:** Store API key in `config.js` (or env), e.g. `flightStatusApiKey: process.env.AVIATIONSTACK_KEY || '...'`. Never send key to frontend.

---

## 8. Module Architecture

### 8.1 Node helper (backend)

- **Start:** Resolve auth path; load credentials + token; create Google OAuth2 client and Calendar API client; resolve calendar IDs (from config or from MMM-GoogleCalendar config).
- **Loop (e.g. every 10–15 min):**  
  1. For each calendar ID, call `calendar.events.list()` for today (and optionally tomorrow).  
  2. Run flight detection on each event; collect list of `{ flightIata, date, label, calendarName }` (dedupe by flightIata+date).  
  3. For each unique (flightIata, date), call AviationStack (or cached result if recent).  
  4. Build payload: `{ flights: [ { flightIata, date, label, calendarName, status, departure, arrival, ... } ] }.`  
  5. `sendSocketNotification('FLIGHT_STATUS', payload)` to frontend.
- **Caching:** Cache AviationStack response per (flightIata, date) with a short TTL (e.g. 10–15 min) to avoid hitting rate limits.
- **Errors:** If Google auth fails, log and send `FLIGHT_STATUS_ERROR` (e.g. `auth_failed`). If AviationStack fails, still send calendar-derived flights with `status: 'unknown'` or omit status.

### 8.2 Frontend (MMM-FlightStatus.js)

- **Subscriptions:** `socketNotificationReceived('FLIGHT_STATUS', payload)` and optionally `FLIGHT_STATUS_ERROR`.
- **State:** Store `payload.flights` (and error). If `flights` is empty or undefined, hide the module (or show nothing). If non-empty, show the section.
- **UI:** For each flight: label (or “Flight WN1234”), status (scheduled / departed / in the air / landed), scheduled and actual departure/arrival times, delay, gate. Use existing MagicMirror styles or a small custom CSS.
- **Visibility:** Section only visible when there is at least one flight for today (and optionally tomorrow). No “no flights” message needed if section is hidden.

---

## 9. Config Design

Minimal config, reusing existing auth and calendars:

```javascript
{
  module: 'MMM-FlightStatus',
  position: 'bottom_left',
  config: {
    // Reuse MMM-GoogleCalendar's OAuth token (no second sign-in)
    useCalendarsFrom: 'MMM-GoogleCalendar',  // OR set calendarIds: ['id1', 'id2']
    // Optional: override auth path if token lives elsewhere
    // googleCalendarAuthPath: 'MMM-GoogleCalendar',

    // Flight status API (AviationStack free tier)
    flightStatusApiKey: process.env.AVIATIONSTACK_KEY || 'YOUR_KEY',

    // Intervals (ms)
    calendarFetchIntervalMinutes: 15,
    flightStatusRefreshMinutes: 20,

    // Optional: timezone for "today" (default: server local)
    timezone: 'America/Los_Angeles',

    // Optional: also include tomorrow's flights
    includeTomorrow: false
  }
}
```

- No manual `flights: [...]` list; everything is driven by calendar + detection.

---

## 10. File Structure

```
modules/MMM-FlightStatus/
├── MMM-FlightStatus.js      # Frontend: socket handler, getDom, show/hide by flights length
├── MMM-FlightStatus.css     # Optional styling
├── node_helper.js           # Google auth (reuse path), calendar fetch, flight detection, AviationStack, socket send
├── package.json             # Dependencies: googleapis (same as MMM-GoogleCalendar)
├── helpers.js              # Optional: flight-number regex, airport-code set, normalize flight IATA
└── README.md                # Setup: AviationStack key, useCalendarsFrom, no manual flights
```

No `credentials.json` or `token.json` in this module; they stay in MMM-GoogleCalendar.

---

## 11. Implementation Order

1. **Scaffold:** Create `MMM-FlightStatus` folder, `package.json` (googleapis), empty `node_helper.js` and `MMM-FlightStatus.js`.
2. **Auth reuse:** In node_helper, implement `googleCalendarAuthPath` / path resolution, read credentials + token from MMM-GoogleCalendar dir, create OAuth2 and Calendar client; verify with one `events.list` call (e.g. one calendar, one day).
3. **Calendar IDs:** Implement `useCalendarsFrom` by reading main config and extracting MMM-GoogleCalendar’s `calendars[].calendarID`; add fallback to `config.calendarIds`.
4. **Calendar fetch loop:** For each calendar ID, fetch today’s events; merge and pass to detection step.
5. **Flight detection:** Implement heuristics (flight-number regex, optional airport-code check, “flight” keyword); extract flightIata + date; dedupe; unit-test with sample titles/descriptions.
6. **Flight status:** Add AviationStack client; for each (flightIata, date) call API; normalize response; cache by (flightIata, date) with TTL; send FLIGHT_STATUS payload.
7. **Frontend:** Handle FLIGHT_STATUS and FLIGHT_STATUS_ERROR; show section only when `flights.length > 0`; render status, times, delay, gate.
8. **Config and docs:** Add module to `config.js`, document env/config for API key and `useCalendarsFrom`, and that no manual flight list is needed.

---

## 12. Edge Cases

- **No flight number in event:** Event not used for live status (could still show “Flight – BWI to SEA” with no status if we want that later).
- **AviationStack limit:** Throttle requests (fewer polls, or only poll when mirror is “active”); show last-known status when over limit.
- **Token expired/refreshed:** Rely on googleapis refresh; if we re-read token from disk periodically, we stay in sync with MMM-GoogleCalendar’s writes.
- **Multiple events same flight:** Dedupe by (flightIata, date); one status request per flight.
- **Timezone:** Use config timezone (or server) for “today” so flights at night (e.g. 11 PM) are attributed to the correct calendar day.

---

## 13. Summary

| Concern | Approach |
|--------|----------|
| Auth | Reuse MMM-GoogleCalendar’s `credentials.json` + `token.json` from configurable path. |
| Calendars | Read from MMM-GoogleCalendar config (`useCalendarsFrom`) or explicit `calendarIds`. |
| Flight source | Only from calendar events; no manual flight list. |
| Detection | Flight-number regex + optional airport codes + “flight” keyword; require flight number for status. |
| Status API | AviationStack (or similar) with flight_iata + date; cache; respect rate limits. |
| UI | Section visible only when there are flights; show status and times. |

This gives you the “full shebang”: one-time Google auth (already done for MMM-GoogleCalendar), same calendars, automatic flight detection from event titles/descriptions/locations, and live status throughout the day with no manual config of individual flights.
