# Code Audit — 321Vegan App

**Date:** 2026-07-17
**Scope:** all 123 Dart files in `flutter_app/lib/` (services, helpers, models, pages, widgets, main.dart), plus iOS config and static analysis.
**Ordering:** bugs first by severity, then code improvements.

---

## High-severity bugs

### 1. Rejected subscription receipt grants premium forever — *mitigated 2026-07-17*

> **Fix applied:** unverified receipts now grant premium for at most 48 h (`_pendingReceiptGrace` in `subscription_service.dart`); past that, access waits for backend verification. Not addressed (accepted): rejected receipts are still retried every 5 min while the app runs, receipts are never dropped on 4xx, and the store may redeliver uncompleted purchases (list growth).
**File:** `flutter_app/lib/services/subscription_service.dart:98`, `:221-232`, `:299`

`isSubscribed` returns `true` whenever `_hasPendingReceipt` is set. Receipts are persisted locally *before* backend verification, and no code path ever removes a receipt the backend rejects: a 4xx from `verifySubscription` throws (Dio default `validateStatus`), is caught, and just calls `_startRetryTimer()` again.

**Scenario:** backend rejects a receipt with 400/422 (bad token, refunded purchase) → receipt stays in `pending_receipts` forever → user keeps premium access indefinitely, plus a network request every 5 minutes for the life of the process.

**Related:** `_savePendingReceipt` appends with no dedup, and an unverified purchase is never `completePurchase`d with the store, so the store redelivers it on every launch and the pending-receipts list grows without bound.

### 2. B12 biweekly date picker crashes once the saved start date is in the past — *fixed 2026-07-17*

> **Fix applied:** `_pickStartDate` now clamps the picker's `initialDate` to the next occurrence of the configured weekday when the saved start date is in the past (date-only comparison). The stored anchor date itself is unchanged.
**File:** `flutter_app/lib/pages/app_pages/Profile/b12_reminder_settings_page.dart:832-857`

`_pickStartDate` passes a possibly-past `biweeklyStartDate` as `initialDate` while `firstDate: now`, violating `showDatePicker`'s `initialDate >= firstDate` contract.

**Scenario:** user on biweekly frequency saved a start date; ≥1 day later reopens "Date de début" → Flutter assertion/exception, picker crashes every time until the frequency is changed.

### 3. Cosmetics search: raw text interpolated into SQL — *fixed 2026-07-17*

> **Fix applied:** `queryCosmeticByName` now uses `rawQuery` with bound arguments for both the LIKE term and the INSTR ranking term, and escapes `%`/`_`/`\` in the LIKE pattern (`ESCAPE '\'`). Verified against the real cosmetics DB with quote, keyword, and wildcard inputs.
**File:** `flutter_app/lib/helpers/database_helper.dart:56` (caller: `flutter_app/lib/pages/app_pages/Search/cosmetics.dart:47`)

`queryCosmeticByName` interpolates the raw search text into the `orderBy` clause: `INSTR(LOWER(brand), LOWER("$name"))`.

**Scenario:** typing a double quote (e.g. `l"oreal`) produces malformed SQL → `DatabaseException`, search dies — and since `lastSearchCosmetics` is auto-replayed on page open, the page stays broken until the pref changes. A word that resolves as an identifier (e.g. `brand`) is treated as a column and silently corrupts ordering. `%`/`_` in the LIKE argument are also unescaped wildcards.

**Fix:** `rawQuery` with a bound argument for the INSTR term.

### 4. Offline scan queue race can duplicate or lose scans
**File:** `flutter_app/lib/services/offline_scan_service.dart:91-118` (vs `:132-141`, `:145-165`)

Queue mutations are stale-snapshot read-modify-write of the whole list, despite the header comment claiming id-based removal is concurrency-safe.

**Scenario:** `retryPendingScans` (runs on app start/resume/connectivity change) finishes POSTing event A and calls `removePendingScanEvent`; the user scans during that window so `savePendingScanEvent` also loads `[A]`. Depending on interleaving: A is resurrected (duplicate POST on next retry) or the new scan B is silently lost.

**Fix:** re-read the list immediately before mutating, as `b12_sync_service.dart:256` (`_flush`) already does.

---

## Medium-severity bugs

### Auth / session

- **`deleteAccount` reports success without checking the response** — `flutter_app/lib/services/auth_service.dart:335-373`. `validateStatus: <500` swallows 401/403/404 without throwing (and bypasses the interceptor's token refresh), then the code clears tokens and returns "Compte supprimé avec succès". With an expired token the account still exists server-side while the user believes it's deleted.
- **`getDio()` singleton race** — `flutter_app/lib/services/dio_client.dart:19-27`. Check-then-await: concurrent first calls (which happen every cold start when logged in, via unawaited `AuthService.init()` and `SubscriptionService.init()` calls in `main.dart:33-34`) each build a Dio + `PersistCookieJar` over the same directory. If the refresh-token cookie is rotated via the losing instance's jar, the surviving jar can hold a stale refresh token → next refresh 401s → spurious logout.
- **Unsynchronized double refresh** — `flutter_app/lib/services/auth_service.dart:45-51` with `dio_client.dart:56-63`. The manual startup refresh and the interceptor's 401-triggered refresh share no lock; two `POST /auth/refresh` with the same cookie can run in parallel. If the backend rotates refresh tokens (single-use), the loser 401s → tokens cleared → user logged out despite a successful refresh in the other branch.
- **Retry-after-refresh misclassified as refresh failure** — `flutter_app/lib/services/dio_client.dart:88`, `:111-163`. If the post-refresh retry of the original request throws, the catch treats it as a refresh failure: a 401 for *authorization* (not expiry) reasons triggers a full logout, and any other retry error rejects all queued requests as "Network error".
- **Email regex rejects valid addresses** — `flutter_app/lib/widgets/auth/login_form.dart:106` (same in `register_form.dart:146`, `change_email_modal.dart:145`, `forgot_password_form.dart:111`). `^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$` allows no `+` in the local part and caps TLDs at 4 chars. A user with `name+tag@gmail.com` or `@company.photography` cannot pass form validation at all — locked out despite valid server-side credentials.

### Scanner lifecycle (`flutter_app/lib/pages/app_pages/Scan/`)

- **Scanner restarts behind open modals on app resume** — `scan.dart:76-102`, `:545-561`. `didChangeAppLifecycleState(resumed)` restarts the scanner whenever `_scannerPausedByModal` is false, but that flag is only set by the NonVegan-card callbacks. Every other modal (history/sent/search/vegandex sheets, settings dialog, account prompt, auth sheet, shop confirmation) stops the scanner without setting it. Background the app with a modal open, return → camera scans behind the sheet, `productInfo` is replaced, scan events fire.
- **Stacked dialogs restart the scanner under each other** — `scan.dart:417-428`, `:900-933`. Each dialog from a single scan stops/starts the scanner unconditionally. Logged-out user's 5th scan on a Vegandex product: ProductFoundModal (stop) + AccountPromptDialog 1.5 s later (stop); dismissing the account dialog's `.then` restarts the camera while ProductFoundModal is still up. Same unconditional restart in `_showShopConfirmationDialog.then`.
- **History clear desyncs from the parent page** — `history_modal.dart:41-46` with `scan.dart:1314-1317`. "Effacer" clears SharedPreferences and the modal's local copy but never the parent `ScanPage.scanHistory`; reopening history shows all deleted entries until the next scan triggers `_loadScanHistory()`.
- **FutureBuilder future created inline in `itemBuilder`** — `history_modal.dart:145-146`. Every rebuild (e.g. `_loadBoycottPref`'s setState right after open, or scroll-driven rebuilds) re-runs the SQLite lookup for each of up to 50 rows and flashes spinners. Resolve once (cache futures per barcode or load in `initState`).
- **Stale scores on fast consecutive scans** — `flutter_app/lib/widgets/scaner/product_scores_section.dart:87-117`. `_initForBarcode`/`_fetchScores` have no request-id/barcode guard, so on a barcode change an in-flight fetch for the previous product can resolve last: product B's card displays product A's Nutriscore/Green-score, and a free reveal is consumed against the old EAN (line 108). `MapSearchBar` already has the correct request-id pattern to copy.

### B12

- **Biweekly reminder chain silently stops after one firing** — `flutter_app/lib/services/b12_reminder_service.dart:247-259` (with `:214-227`). `markNotificationReceived()` is called from nowhere, so `b12_last_notification_date` is never written and the fallback branch is dead. The one-shot biweekly notification is only rechained by `checkAndRescheduleIfNeeded` on home-page resume — a user who doesn't open the app gets no further reminders.
- **Frequency persisted by enum index, mismatched defaults** — `flutter_app/lib/models/b12_reminder_settings.dart:44`. `ReminderFrequency.values[json['frequency'] ?? 1]` defaults a missing key to weekly while the class default is daily, and throws `RangeError` on any out-of-range value; that error is swallowed by the catch in `b12_reminder_service.dart:34-39`, which returns `enabled: false` → reminders silently turn off. Persist `frequency.name` and align defaults.

### Other

- **Vegan-time counter can show negative days** — `flutter_app/lib/helpers/time_counter/time_counter.dart:42-45`. Single day-borrow uses the length of the month before `now`: veganSince = Jan 31 viewed Mar 1 → "1 mois / -2 jours". Reproducible every March for anyone whose date is the 29th–31st. Displayed on home (`home.dart:545`) and the share card (`share_home_card.dart:238`).
- **Unknown subscription status maps to `expired`** — `flutter_app/lib/models/subscription.dart:20-21`. Any new backend status (e.g. an upcoming trial state) → `isActive == false` → paying/trialing user silently loses premium. At minimum log unknown values; relevant to the in-progress free-trial work.
- **iOS `areNotificationsEnabled()` unconditionally returns true** — `flutter_app/lib/services/notification_service.dart:354-368`. B12 settings UI reports reminders active and `AnniversaryService.rescheduleIfNeeded` schedules into the void when the user denied permission.
- **`NSAllowsArbitraryLoads = true`** — `flutter_app/ios/Runner/Info.plist:37-38`. Disables App Transport Security app-wide (all cleartext HTTP allowed). If one host needs it, scope with `NSExceptionDomains` instead.

### setState-after-dispose cluster (~10 confirmed spots, one sweep fixes all)

Async loaders/savers calling `setState` after an `await` with no `mounted` guard. Pages living in a TabBarView are disposed when the user swipes away mid-request; modals when dismissed mid-load.

| File | Location | Trigger |
|---|---|---|
| `pages/app_pages/Profile/b12_reminder_settings_page.dart` | `:34-38`, `:64-67`, `:79` | pop page while save/schedule in flight |
| `pages/app_pages/Profile/subscription_page.dart` | `:130-133` | purchase throws after page popped (adjacent `finally` *is* guarded) |
| `pages/app_pages/Partners/partners_page.dart` | `:28-38` | swipe away tab before API responds |
| `pages/app_pages/Scan/scan.dart` | `:343-392`, `:623-643` | six pref/cache loaders + `_checkVeganStatusOffline`; swipe away Scan tab |
| `widgets/theme/theme_selector_modal.dart` | `:72` (+ `:84-90`) | dismiss modal while loading; **also double-disposes `_pageController` and leaks the replacement** |
| `widgets/auth/user_profile.dart` | `:209` | `mounted` checked at `:185` but more awaits follow before setState |
| `widgets/scaner/card_product.dart` | `:422-426` | navigate off scan tab while `tryAddDocument` in flight |
| `widgets/auth/edit_profile_modal.dart` | `:132`, `:56` | dismiss sheet while update pending and it fails |
| `widgets/scaner/info_dialog_button.dart` | `:112-129` | Android activity recreation while camera open (same in `product_info_form_modal.dart:51-68`) |
| `pages/app_pages/Search/cosmetics.dart` | `:38-57` | DB await with no mounted check |

---

## Low-severity bugs

- **Double-tap posts `confirmShop` twice** — `flutter_app/lib/widgets/scaner/shop_confirmation_modal.dart:102-140`. Oui/Non/shop buttons never disabled during the async confirm; during the 1.2 s "Merci !" animation buttons stay tappable → duplicate shop link/creation server-side.
- **"Avis" tab loads reviews twice per open** — `flutter_app/lib/widgets/map/shop_detail_sheet.dart:54-58`. TabController listener fires twice per switch (index change + animation settle) and the `_isLoadingReviews` condition doesn't block the second pass → duplicate `getShopReviews` + `getMyShopReview` calls.
- **`SeasonalIcon` keeps the old season's asset after theme change** — `flutter_app/lib/widgets/theme/seasonal_icon.dart:140-147`. `didUpdateWidget` resets animations but never recomputes `_resolvedAsset` (set only in `initState`) — e.g. a pumpkin spinning like a snowflake until the widget is recreated.
- **Scan-count seed dedup can drop unsynced increments** — `flutter_app/lib/services/scan_count_sync_service.dart:103-106`. Heuristic `serverCount == localTotal` misfires when an existing account's server counter coincidentally equals the local total → unsynced increments discarded.
- **Null `last_scanned_at` renders as "scanned today"** — `flutter_app/lib/models/shops/shop_scan_summary.dart:21-24`. Falls back to `DateTime.now()` so `daysSinceLastScan == 0`; should be nullable like `lastNotFoundAt`.
- **One malformed entry kills the whole additives list** — `flutter_app/lib/models/e_number.dart:26-39`. `fromJson` reads several fields unguarded; a single bad item in the bundled `e_numbers.json` makes `fromJsonList` throw → additives search and validator lookup show nothing. Fail per-item instead.
- **Keystroke searches lack debounce/sequencing** — `flutter_app/lib/pages/app_pages/Profile/product_review/brand_widgets.dart:149-162` (same pattern in `Search/cosmetics.dart:38-57`). An older slow response can overwrite results of a newer query.
- **Undisposed `TextEditingController`s** — `Search/additives.dart:19`, `Search/cosmetics.dart:17` (no `dispose()` override at all), and `widgets/map/shop_detail_sheet.dart:193-194` (`commentController` per dialog open).
- **Membership prompt can be consumed without showing** — `flutter_app/lib/pages/app_pages/home.dart:125-165`. Pending flag cleared before the dialog is guaranteed to display; unguarded `videoController.initialize()` can throw.
- **`SubscriptionService.onSubscriptionChanged` is a single static slot** — `flutter_app/lib/pages/app_pages/Profile/subscription_page.dart:73-82`. A second page instance overwrites it and its dispose nulls it, silencing the surviving instance.
- **Both TabBarView ListViews share the sheet's scrollController** — `flutter_app/lib/widgets/map/shop_detail_sheet.dart:1266-1271`. During a tab swipe both are attached (multi-position controller) — can glitch drag-extent tracking or trip the single-position assert.
- **`addSelectedDateToPrefs(null)` clears locally but never on backend** — `flutter_app/lib/helpers/preference_helper.dart:22-29`. Latent today (all call sites pass non-null), but login sync copies the backend value back — a future "clear my date" UI would see the date resurrect.

---

## Code improvements

### High value

1. **Databases re-extracted on every cold start** — `flutter_app/lib/helpers/database_helper.dart:36-40` (+ `main.dart:31-32`). Both gzipped DBs (`vegan_products.db.gz` is 7.2 MB compressed) are loaded fully into memory, gunzipped with the pure-Dart synchronous `GZipDecoder`, and rewritten to disk on every launch, on the main isolate, **before `runApp`**. Extract only when the bundled asset changes (store app version / asset hash in prefs) and/or do it in an isolate. Probably the single biggest perceived-performance win available.
2. **No timeout on any `package:http` call** — `flutter_app/lib/services/api_service.dart:56` and all `http.*` calls (`:161`, `:214`, `:262`, `:355`, `:386`, `:462`, `:485`, `:508`). Dio paths have 10 s; a stalled connection hangs `postScanEvent` indefinitely and blocks `retryPendingScans` passes.
3. **Auth-header boilerplate duplicated across `api_service.dart`** — `:527-528` and ~10 other methods. Half read `prefs.getString('access_token')` directly, half use `AuthService.accessToken`, each with 8 duplicated lines. One shared helper — or a Dio interceptor injecting the header.
4. **Auth bottom-sheet duplicated three times** — `scan.dart:1374-1401`, `subscription_page.dart:1139-1184`, plus a variant in `on_boarding_page.dart:350-380`. Extract one shared auth-sheet widget.
5. **Home tab inlined in `build`** — `flutter_app/lib/pages/app_pages/home.dart:422-793`. ~370 lines (support banner, counter, share button, date editor) inside `MyHomePageState.build`; the 1-minute `_timer` setState rebuilds all five tabs' scaffolding. Extract a `HomeTab` widget.

### Smaller

- **Snow-globe overlay rebuilds at 60 fps via per-frame `setState`** — `flutter_app/lib/widgets/theme/snow_globe_overlay.dart:136`. Use a `Listenable`-driven `CustomPaint`/`Flow`; noticeable with several themed cards on screen.
- **`+ 60` magic number on the public subscriber counter** — `flutter_app/lib/services/api_service.dart:512`. `return data['count'] + 60 as int;` — uncommented inflation; null `count` silently becomes null via the blanket catch.
- **Partners "new" badge driven by a hardcoded date** — `flutter_app/lib/helpers/preference_helper.dart:305-308`. `DateTime(2026, 07, 05)` requires a code edit + release per partner update; drive it from data (partner list hash or API field).
- **B12 reconcile is O(n²) prefs churn** — `flutter_app/lib/services/b12_sync_service.dart:156-161`. `_reconcile` enqueues days one at a time, each `_enqueue` re-reading/decoding/rewriting the whole prefs list; the API already accepts a list — batch it.
- **Sequential prefs reads in shop sheet** — `flutter_app/lib/widgets/map/shop_detail_sheet.dart:83-94`. Two awaits per scanned product in a loop (2N); batch with `Future.wait` or one read.
- **`products_of_interest_cache.dart` duplication + stale comment** — `:15-37` vs `:80-96`: `initializeAtStartup` duplicates `_updateFromApiInBackground` almost verbatim; doc comment says 24 h while `_cacheExpiry` is 12 h.
- **Badge year math inconsistent with the counter** — `flutter_app/lib/models/badge.dart:30`, `:53`, `:79`. `inDays ~/ 365` drifts from calendar math: after 8+ years the "X ans" badge unlocks ~2 days after the home counter shows X years.
- **Badge icon + greyscale matrix duplicated** — `flutter_app/lib/widgets/auth/user_profile.dart:2167-2188` and `:2265-2286`; the 2,456-line file would generally benefit from splitting.
- **Dead code / unused API:** the `success == false` branch of `addCodeToPreferences` is unreachable (`preference_helper.dart:119-120`); `User.toJson` is unused and drops `role`, `subscription_bypass`, `scan_count` (`user.dart:77-90`) — a trap if anyone starts caching users with it.
- **Unnecessary import** — `flutter_app/lib/widgets/auth/user_profile.dart:2` (the only `flutter analyze` finding).

---

## Checked and found correct (not bugs)

- `.env` (API key) is gitignored, not tracked; no hardcoded secrets in `lib/` (all via dotenv).
- B12 streak math, `calendarDaysBetween` (UTC-normalized DST handling), anniversary Feb-29 pinning, biweekly week-parity math.
- `B12SyncService`/`ScanCountSyncService` sync chaining (`_lastSync`); scan-count increments (SharedPreferences memory-cache synchronous within one expression).
- `codes_with_status` 300-item trim and JSON round-trip; scan-history read/write symmetry; weekly free-score-reveal reset; `ThemeHelper.getCurrentSeason` boundaries.
- `B12ReminderSettings.copyWith` sentinel handling; `ValidatingPhase` keyed per product; `MapSearchBar` stale-response guard; map/partners loading spinners can't strand (ApiService returns `[]` on error).

---

## Suggested fix order

1. High-severity bugs 1–4 (revenue integrity, hard crash, broken search, data loss).
2. The `mounted`-guard sweep (mechanical, one pass, ~10 crash sites).
3. Auth/session races and `deleteAccount` status check.
4. Scanner lifecycle (single source of truth for pause/resume instead of scattered stop/start).
5. Startup DB extraction skip (biggest perf win).
6. Email regex, B12 frequency persistence, unknown-subscription-status logging (small, high user impact).
