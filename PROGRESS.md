# Progress log

Session notes covering work across both **pharma_exchange_egypt** (mobile app)
and **pharma_exchange_admin** (admin dashboard, separate project at
`D:\flutter_projects\pharma_exchange_admin`). Newest entries on top.

## 2026-09-18 (later) — Admin dashboard catch-up + real push notifications

### Admin dashboard (`pharma_exchange_admin`)

Migration 0035 gave deals their own `deal_status` type. The admin's
`deal_summary.dart` still had the old three-value enum with a
`_ => DealState.reserved` catch-all, so `pending`, `accepted` and `declined`
all silently collapsed into "reserved" — **a declined request counted as a
live deal**.

- `deal_summary.dart` — full 5-state enum with labels, `isConcluded`, and an
  `isOverdue` helper; unknown values now fall to `cancelled` rather than
  inflating a live bucket. Added `expires_at` to the model and the select.
- `dashboard_stats.dart` — **completion rate was wrong**, not just mislabelled:
  `completedDeals / deals.length` counted requests still waiting on a seller
  (and ones the seller declined) as failures to complete, so the rate would
  sag as soon as request volume grew. Denominator is now deals that actually
  reached a decision. Added `dealStateBreakdown`, `dealsAwaitingSeller`,
  `dealsOverdue`.
- `dashboard_screen.dart` — deals-by-state breakdown, plus a backlog note
  that turns red when pending requests are past their deadline (which would
  mean the 15-minute sweep job is wedged).
- 8 new l10n keys, EN/AR parity 254/254. `flutter analyze` clean, 10 tests
  pass (was 1 placeholder).

### Push notifications — the real gap, now closed

`notify_new_message()` and `respond_to_deal()` only ever inserted a
`notifications` row. The only code that actually sent FCM was the admin
broadcast function, so with the app backgrounded or closed a pharmacy was
told nothing. Survivable when a request reserved the listing outright;
not survivable with 0035's 48-hour seller response window.

- `supabase/functions/_shared/fcm.ts` — **new.** One FCM implementation for
  both senders: 500-token chunking, stale-token pruning, constant-time
  secret compare.
- `supabase/functions/send-push/index.ts` — **new, deployed.** Called by the
  database, not the client. `verify_jwt: false` (Postgres has no JWT to
  present); gated on a Vault-held shared secret in `x-push-secret`, compared
  in constant time, **failing closed** if `PUSH_HOOK_SECRET` is unset.
- `broadcast-notification` — refactored onto the shared module, redeployed
  (v4). Still `verify_jwt: true` + `is_admin()` check.
- `0042_push_on_notification.sql` — **APPLIED.** `pg_net` + AFTER INSERT
  trigger on `notifications`. Skips `admin_broadcast` (the broadcast function
  pushes those itself — otherwise every one would double).
- `main.dart` — notification taps are now handled at all
  (`getInitialMessage` + `onMessageOpenedApp`), routing on the `deal_id` /
  `listing_id` data payload. Uses `push` not `go` so the router's redirect
  still gets to veto — a suspended pharmacy tapping an old notification must
  not land in a deal thread.

**INSERT-only is deliberate:** 0035 collapses consecutive unread messages in
a thread into one notification row, so this gives one push per conversation
until it's read, rather than one per message. Deal events each write their
own row and so each still push.

Verified: `pg_net` installed, trigger present, anon cannot execute the
trigger function, and — the property that matters — an insert into
`notifications` with the hook unconfigured **succeeds without error**
(tested with a deliberately rolled-back insert). A push that can't be sent
must never be able to fail the chat message that triggered it.

### Still needs console access (push is inert until all three are set)

```
-- 1. Vault, so the trigger knows where to post and how to authenticate
select vault.create_secret('https://tazrooozwrcekxmdwzsu.supabase.co', 'project_url');
select vault.create_secret('<random string>', 'push_hook_secret');
```
```
# 2. Same secret on the function
supabase secrets set PUSH_HOOK_SECRET='<the same random string>'

# 3. Firebase service account — was already outstanding for broadcasts
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"
```

Plus, still outstanding: iOS `GoogleService-Info.plist` + APNs key + Push
capability; a real release keystore; and the leaked-password toggle in
Authentication → Policies (the last remaining security advisor item).

## 2026-09-18 — Full bug audit + fixes (migrations 0034–0040, ~30 app files)

Audited the app against the live database and fixed everything found except
the two items scoped out by the user: partial quantities, and licence expiry
(the product doesn't actually have a pharmacy licence expiry).

### Confirmed against live data, not theoretical

- **8 of 8 reserved listings** were 8–9 days past `reserved_until`, with no
  `pg_cron` installed and nothing anywhere reading the column — 27% of the
  marketplace permanently locked and invisible to search.
- **`walidmadany@hotmail.com`** — confirmed auth user, no `pharmacies` row,
  not an admin. The orphaned-registration bug, already in production data.
- **2 listings `available` past their expiry date.** Because
  `listings_expiry_date_check` was a volatile CHECK re-evaluated on every
  UPDATE (not just INSERT), those rows were frozen — every write to them
  failed, including reserving, cancelling and editing.

### Migrations (supabase/migrations/)

- `0034_pharmacy_status_enforcement.sql` — **APPLIED.** `is_approved_pharmacy()`,
  `get_my_status()`, approved-only write policies on listings/messages.
- `0035_deal_lifecycle_v2.sql` — `deal_status` enum; seller accept/decline
  step; a request no longer reserves the listing; system messages
  (`sender_id = null`); notifications collapsed per thread.
- `0036_listing_integrity.sql` — volatile CHECK → BEFORE INSERT trigger;
  `price > 0`; `update_my_listing()` / `delete_my_listing()`; expired stock
  filtered out of search.
- `0037_controlled_substance_enforcement.sql` — controlled-term table +
  blocking trigger; `find_or_create_drug` no longer hardcodes
  `is_controlled = false`.
- `0038_deal_expiry_sweep.sql` — `pg_cron` every 15 min, plus a lazy release
  inside `request_listing`, plus a backfill for the 8 stuck listings.
- `0039_account_deletion_and_recovery.sql` — `delete_my_account()`,
  idempotent `complete_my_registration()`.
- `0040_hardening.sql` — revoke `anon` EXECUTE on 27 security-definer
  functions, drop the stale `search_listings` overload, paged
  notifications/messages RPCs, bucket size + MIME limits, dispute rate limit.

- `0041_grant_cleanup.sql` — **APPLIED.** Post-0040 grant tightening, see below.

**All applied and verified against the live project on 2026-09-18.** 0034 and
0041 went through the MCP connector; 0035–0040 were bundled as
`supabase/migrations/PENDING_0035_to_0040.sql` and run by the user in the
Studio SQL editor (the sandbox's auto-mode classifier refuses schema-mutating
applies — see the memory note).

Verified after the run:

| Check | Result |
|---|---|
| Stuck reservations | **0** (was 8). Available listings 19 → 27 |
| `cron.job` | `*/15 * * * *` → `release_expired_deals()`, active |
| Volatile `listings_expiry_date_check` | dropped, replaced by BEFORE INSERT trigger |
| Expired stock leaking into `search_listings` | **0 of 25 rows** |
| Controlled-substance re-scan | 6 drugs re-flagged, 69 terms seeded, no live listings needed pulling |
| `search_listings` overloads | 1 (stale pre-0030 one dropped) |
| Anon-executable SECURITY DEFINER fns | **27 → 3**, and all 3 are PostGIS built-ins |

`0041` exists because 0040's revoke loop only took EXECUTE from `PUBLIC` and
`anon`. Supabase ships an `alter default privileges ... grant all on functions
to anon, authenticated, service_role` rule, so every function *also* gets a
direct grant to `authenticated` at creation — which has to be revoked by name.
That had left `release_expired_deals()` (the cron sweep) callable by any
signed-in pharmacy, plus seven trigger functions sitting on the REST surface.
Both search_path advisor warnings cleared at the same time.

Two listings remain `available` with a past expiry date. That's intended: they
are filtered out of search, and leaving them editable means the seller can
correct the date via `update_my_listing()` rather than losing the listing.

### App changes

Router redirect guard (there was none at all — every route was deep-linkable
with no session, and KYC approval was bypassed by signing out and back in);
`SessionController` + `onAuthStateChange`; `AppError` code→l10n mapping so raw
Postgres/Storage exception text no longer reaches users; `NotFoundException`
instead of `.first` `StateError` crashes on empty RPC results; orphaned-upload
cleanup on failed inserts; push-token unregister on sign-out (the device kept
receiving the previous account's pushes); account deletion UI (App Store
5.1.1(v) blocker); listing edit/delete UI; accept/decline UI with expiry
countdown; paged notifications and messages; `loadMore` in-flight guard;
locale preload (no more LTR→RTL flash on cold start); password-reset deep link
(`AndroidManifest.xml` + `Info.plist` + `redirectTo`); Firebase init guard so
iOS no longer hard-crashes on launch without `GoogleService-Info.plist`;
release signing config + ProGuard rules (was signing with the debug keystore).

`flutter analyze` clean. 26 tests pass (was 1 default smoke test). EN/AR ARB
parity 447/447.

### Deliberately not done

**Dark mode.** Roughly ninety widgets paint from the `AppColors` static
constants rather than `Theme.of(context)`, so adding a `darkTheme` and
flipping `themeMode` would produce a dark scaffold with white cards and
near-white text on them — worse than light-only. It's a palette migration
(`AppColors` → `ThemeExtension`, then convert the call sites), not a flag.
`themeMode: ThemeMode.light` is now explicit in `main.dart` with that
reasoning in a comment.


## 2026-09-07 — Test data: reset + seed scripts

Wrote three one-off SQL scripts (NOT migrations — not in `supabase/migrations/`,
meant to be pasted into the Supabase Studio SQL editor by hand) to get a clean
testing environment:

- **`reset_test_data.sql`** — deletes every pharmacy account except
  `walid@test.com` (full `auth.users` deletion, not just profile data), every
  listing not owned by that pharmacy, and everything that depends on either
  (deals, chat messages, ratings, disputes, notifications, favorites,
  price-drop subscriptions, push tokens, compliance flags, price history).
  Admins untouched. Guarded — aborts if the kept email doesn't resolve to
  exactly one pharmacy, so a typo can't wipe everyone.
- **`seed_dummy_listings.sql`** — 10 listings for `walid@test.com` across
  sell/buy/barter, real Egyptian pharmacy trade names resolved through the
  app's own `find_or_create_drug()` RPC, placeholder photos via
  picsum.photos (not uploaded to Supabase Storage — just URLs in
  `photo_url`).
- **`seed_test_pharmacies.sql`** — creates 3 more fully-usable logins
  (`pharmacy2/3/4@test.com`, password `Test@1234` for all), status set
  straight to `approved` (skips KYC review), 3 listings each, 9 total.
  Written directly against `auth.users`/`auth.identities` since there's no
  service-role/Admin API access available — a known community technique,
  not Supabase's official path, so login isn't guaranteed to work on every
  Supabase version. Fallback if it doesn't: Studio's Authentication → Add
  user, then re-run just the `pharmacies`/listings inserts for that account.

**Not yet confirmed to actually run** — this session never had working
Supabase connectivity (see below), so none of these three scripts have been
executed or verified against the real database yet. First fix to `reset_test_data.sql`
(temp-table version) hit `relation "_keep" does not exist` in the Studio SQL
editor — rewritten as a single `DO $$ ... $$` block, which should be immune to
that (Postgres treats it as one statement), but that fix itself is also unverified.

## 2026-09-07 — Admin dashboard: fixed PGRST201 ambiguous embed

`pharma_exchange_admin`'s dashboard was throwing on load:
`Could not embed because more than one relationship was found for 'listings' and 'pharmacies'`.

Root cause: `favorites` (mobile app's migration `0026_favorites.sql`) added a
second, many-to-many path between `listings` and `pharmacies`, on top of the
original direct FK — so PostgREST's `pharmacies(...)` embed shorthand became
ambiguous. Fixed in two places by qualifying the embed with the explicit FK
name (`pharmacies!listings_pharmacy_id_fkey(...)`):

- `lib/features/listings/listings_controller.dart` — the query actually
  failing on dashboard load.
- `lib/features/disputes/disputes_controller.dart` — same bug, nested inside
  a `deals → listings → seller:pharmacies` embed; hadn't errored yet only
  because the dashboard's stats provider awaits controllers sequentially and
  never got past the listings one.

`flutter analyze` clean on both files; dev server restarted and sign-in
screen renders (couldn't verify past login — no admin credentials this
session).

## 2026-09-06/07 — Builds: Android done, iOS scaffolded

- **Android**: built successfully — `build/app/outputs/flutter-apk/app-release.apk`
  (~59MB). **Signed with the debug keystore** (`android/app/build.gradle.kts`
  has a `// TODO: Add your own signing config` placeholder) — fine for
  sideloading/testing, **not Play Store-ready** without a real release
  keystore.
- **iOS**: can't be built from this Windows machine at all (`flutter build ios`
  requires macOS/Xcode). Set up a path forward instead:
  - Git-initialized the repo (it wasn't one before this session) and made an
    initial commit on branch `main`. **Not yet pushed** — no GitHub remote
    configured yet; user needs to create the repo and hand back the URL.
  - Added `.github/workflows/ios-build.yml` — builds an *unsigned* iOS
    artifact (`--no-codesign`) on a `macos-14` GitHub Actions runner, since
    there's no Mac available locally. Signing/App Store submission is a
    separate, not-yet-done follow-up (needs Apple Developer credentials +
    certificates).
  - Fixed a real gap in `ios/Runner/Info.plist`: added the missing
    `NSLocationWhenInUseUsageDescription` — the app already uses
    `Geolocator` (KYC address pin, "nearest" search) and iOS silently kills
    the process on a location request without this key present.
  - **Flagged but not fixed** (needs manual Apple/Firebase console steps I
    can't do from here): no `ios/Runner/GoogleService-Info.plist` exists yet
    → `Firebase.initializeApp()` will throw on iOS until one is generated
    and added to the Xcode project. Also no Push Notifications
    capability/entitlements or APNs key configured yet — needed for
    `firebase_messaging` to actually deliver pushes on iOS (not a build
    blocker, just a missing-feature gap).

## 2026-09-06 — Search filters + product screen: dropped active ingredient, upgraded concentration

Investigated why the active-ingredient filter/field felt broken: the
~23,600-row `drug_catalog` reference table (migration `0022_drug_catalog.sql`)
has **no active-ingredient data at all**, and `find_or_create_drug()` — the
function every self-service listing creation calls — doesn't even accept an
active-ingredient parameter. So every listing created through the normal
flow gets `active_ingredient = null` forever, not just occasionally.

Decision (confirmed with user): drop active-ingredient as a search filter
entirely rather than leave a filter that silently matches nothing; leave it
on the product/listing detail screen exactly as before (shown only when
present, no visual weight); upgrade the concentration filter — which *is*
reliably populated — from a blind free-text box into a real autocomplete
picker backed by distinct catalog values (same search-as-you-type pattern as
the Add Medicine flow's drug picker).

Changed: `lib/features/search/search_controller.dart` (`SearchFilters` model),
`lib/features/listings/listings_query.dart`, `lib/features/search/search_screen.dart`
(new `_ConcentrationPickerSheet`), `lib/features/drugs/drug_catalog_search.dart`
(new `searchConcentrations`/`fetchInitialConcentrations`). Removed the now-dead
`fieldActiveIngredient` l10n key, added `mapPinnedCount`-style plural-safe
`searchAnyConcentration`/`searchConcentrationHint`/`searchUseConcentration`
(EN + AR). `flutter analyze` clean.

## 2026-09-06 — Map enhancements (search, KYC, chat)

Polished all three `flutter_map` usages in the app with a shared, reusable
look (new `lib/core/widgets/map_pin.dart`, `map_controls.dart`):

- **Search results map** (`search_map_view.dart`) — gradient "balloon" pins
  instead of a stock icon, zoom-aware grid clustering (no compatible
  `flutter_map_marker_cluster` version for this `latlong2` pin, so it's a
  small hand-rolled bucketing helper instead), floating zoom controls + a
  "fit all pins" button, a results-count pill, and a nicer selected-listing
  card.
- **KYC address pin-drop** (`address_step.dart`) — switched from
  tap-to-place to the Google Maps/Careem pattern: pin fixed at the map's
  visual center, map pans underneath, pin lifts while dragging and drops on
  release. Fixed the marker-anchor math so the pin's *tip* (not its icon's
  bounding-box center) lands exactly on the coordinate that gets saved.
- **Chat shared-location preview** (`chat_thread_screen.dart`) — same new pin
  style, gradient pill label instead of a flat black bar.

Added `mapPinnedCount` l10n key (EN/AR, proper plural forms). `flutter analyze`
clean throughout.

## Known limitation across this whole session

**No working Supabase network access** in this sandbox (the Supabase MCP
connector times out; the mobile app's own `Supabase.initialize()` call hangs
past first-frame render for the same reason). This blocked:
- Live browser verification of the map changes and the filter/concentration
  picker in the actual running mobile app.
- Any direct database access — every SQL script above had to be handed off
  as a file for the user to paste into Supabase Studio themselves, and none
  of the three test-data scripts have been confirmed to actually run yet.

The admin dashboard, by contrast, *did* render successfully in this
session's browser (reached the sign-in screen, and after user login,
surfaced the PGRST201 bug that got fixed) — so whatever blocks the mobile
app's Supabase call isn't blocking everything equally; worth re-testing the
mobile app's live preview next session in case it was transient.
