# Charter Booking — Flutter UI (Phase 0, design round 2)

This is the real Flutter implementation of the design system and primary-journey
screens for the Bus & Tempo Traveller Charter Booking App, replacing the earlier
HTML prototype with production-grade widget code.

## Scope of this delivery

**Included** — a complete, consistent design system and the same 11 primary-journey
screens as the earlier clickable prototype, now as real Flutter widgets:

- **Design system** (`lib/core/theme/`) — colour, type, spacing and radius tokens,
  assembled into one `ThemeData`. Every screen reads style from this theme; nothing
  is styled inline.
- **Shared components** (`lib/core/widgets/`) — buttons, cards, form fields, status
  badges, the status stepper — used consistently across both shells.
- **Customer shell** (`lib/features/customer/`) — mobile entry, OTP, home/search,
  results, hold, booking detail, my bookings.
- **Admin shell** (`lib/features/admin/`) — login, booking queue, booking detail
  (cost confirmation + payment recording), bus calendar.

**Not included yet** — state management (Riverpod), routing (go_router), Firebase
wiring, and the remaining screens from the BRD's full inventory (masters, reports,
settings, terms/privacy, account deletion). Screens here use local `setState` and
`Navigator.push` only, with the sample data in `lib/data/mock_data.dart` standing in
for the backend. This matches Phase 0 of the BRD — UI and design system first,
architecture wiring in Phase 1.

## Design system in brief

- **One accent colour** (indigo, `#3F3BF0`) used only for primary actions and
  selected states — everything else is near-black text on white/near-white
  surfaces.
- **One typeface** (Inter, via `google_fonts`) carrying the whole app; hierarchy
  comes from weight and size, not from mixing fonts.
- **Hairline borders instead of shadows.** `CardTheme` and `AppCard` use a 1px
  border and zero elevation everywhere — there is no default Material drop shadow
  left active anywhere in the theme.
- **A single, moderate radius scale** (10 / 14px) applied consistently. No
  pill-shaped buttons, no mixed-radius clutter.
- **Status badges are small tinted rounded rects**, not pills — they read as a
  data field, not a decoration.

## Running it

This sandbox has no internet access to `pub.dev`, so the packages could not be
fetched or compiled here — this code has been reviewed for syntax and import
correctness but not run through `flutter analyze` or a live build. To run it:

```bash
flutter pub get
flutter run
```

Requires Flutter 3.19+ (Dart 3.3+). The only third-party dependency is
`google_fonts`; everything else is Flutter SDK.

## What to review

Open `lib/main.dart` — it launches on a "Choose an experience" screen (clearly
marked in code as prototype-only, not part of the product) so both shells can be
reviewed from one build. From there:

- **Customer:** mobile number → OTP → Home/Search → Results → Hold (live
  countdown) → Booking detail (status stepper, driver card, payment ledger) →
  My Bookings.
- **Admin:** Login → Booking queue (hold timers) → Booking detail (cost
  confirmation + record payment) → Bus calendar (availability grid).

## Next steps

1. Sign off on this UI, or flag specific changes.
2. Remaining BRD screens (vendor/bus/driver master forms, reports, settings,
   terms/privacy) designed in the same system.
3. Phase 1 (Foundation) wires this UI to Riverpod, go_router and Firebase per
   the BRD's architecture section.

## Sign-in configuration (MSG91 OTP + biometric unlock)

Customers sign in with a real SMS OTP through the **MSG91 OTP Widget**
(`sendotp_flutter_sdk`), then may turn on fingerprint / Face ID so later
launches need no OTP. The widget ID and token auth are built in as defaults
(`lib/features/auth/data/auth_config.dart`); override them at build time with:

```bash
flutter run \
  --dart-define=MSG91_WIDGET_ID=<widget id> \
  --dart-define=MSG91_TOKEN_AUTH=<widget token auth>
```

Optional, with defaults:

| Define | Default | Meaning |
|---|---|---|
| `OTP_LENGTH` | `4` | Must match the OTP length on the MSG91 widget |
| `OTP_RESEND_SECONDS` | `30` | Wait before "Resend via SMS" |
| `OTP_VOICE_RETRY` | `false` | Show "Get a call" (enable voice in the widget first) |
| `BIOMETRIC_RELOCK_MINUTES` | `5` | Ask for biometrics again after this long in the background |
| `MSG91_FAKE` | `false` | Demo mode: no SMS, any code works except `0000` (wrong) and `9999` (expired) |

A build without `MSG91_WIDGET_ID` / `MSG91_TOKEN_AUTH` (and without
`MSG91_FAKE=true`) shows a configuration error screen instead of the app.
In the MSG91 dashboard the widget needs **Mobile Integration on** and
**Captcha off**.

**The MSG91 Authkey is never in the app.** It lives only in the
`verifyMsg91Token` Cloud Function (`functions/`), set with
`firebase functions:secrets:set MSG91_AUTHKEY`. Until Firebase is wired the
app uses an on-device stand-in (`LocalTokenVerifier`, behind the
`TokenVerifier` interface) that accepts any token, so **sessions are not
yet verified server-side**.

## Firebase backend (Stage 1)

Project `driveon-charter` (Firestore in `asia-south1`). App ID on every
platform: `com.busbooking.driveon.charter`. The generated
`google-services.json` / `GoogleService-Info.plist` are gitignored; recreate
them with `flutterfire configure --project=driveon-charter`.

The app signs in against Firebase by default. For an offline demo with the
on-device stand-in, build with `--dart-define=USE_FIREBASE=false`.

| What | Where |
|---|---|
| Customer sign-in: MSG91 token -> Firebase custom token, role claim | `functions/src/verifyMsg91Token.ts` |
| Admin-only role changes; account deletion with data erasure | `functions/src/setUserRole.ts`, `deleteAccount.ts` |
| Baseline rules: deny everything except a customer's own `users/{uid}` | `firestore.rules` |
| App side | `lib/features/auth/data/firebase_auth_repository.dart` |

**Run it locally against the emulators** (needs Node and JDK 21+):

```bash
cd functions && npm install && npm run build && cd ..
firebase emulators:start          # auth 9099, functions 5001, firestore 8085
flutter run \
  --dart-define=USE_FIREBASE=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 \
  --dart-define=MSG91_FAKE=true     # 10.0.2.2 instead of 127.0.0.1 on an Android emulator
```

With `MSG91_FAKE=true` the emulator's function accepts the fake token and
trusts the number the app sends. That branch only runs when
`FUNCTIONS_EMULATOR=true`, so it cannot run in production.

**Tests**

```bash
cd rules-tests && npm install
npm test        # security rules
npm run e2e     # functions + rules + auth together, in the emulators
```

**Staff access** is by the same mobile OTP as customers (staff tap "Staff sign
in"). After MSG91 verifies the number, `verifyMsg91Token` checks it against the
`staff` collection in Firestore: a document whose ID is the number with country
code (e.g. `919876543210`) and fields `name` (string) and `active` (boolean,
must be `true`). A number that is not on the list is refused even with a
correct OTP. The collection is closed to every client (rules deny it); add or
deactivate staff in the Firebase console (Firestore Database > `staff`).
Staff and customer accounts are separate (`staff_...` / `cust_...`).

Note: deactivating a staff member stops new sign-ins immediately, but a phone
that is already signed in keeps its role until its token refreshes (up to an
hour) or the user is signed out from Authentication > Users.

For the emulator tests, `rules-tests/e2e.test.js` seeds its own staff entries.

## Master data in Firestore (Stage 2)

Buses, vendors, drivers, locations, blackouts, notification templates, package
rates, FAQs and the app config are read from and written to Firestore. Bookings,
payments, notifications and reports are still in memory until Stages 4-6.

| Collection | Read | Write |
|---|---|---|
| `buses`, `locations`, `blackouts`, `packages`, `faqs`, `config/app` | any signed-in user | staff |
| `vendors`, `drivers`, `templates`, `busAdmin` (bus GPS links) | staff | staff |
| `auditLog` | staff | server only |
| `users/{uid}/recents` | that customer | that customer |

Every staff write must carry `updatedBy` (their own uid) and `updatedAt` (server
time); the rules enforce it. A Cloud Function trigger (`functions/src/audit.ts`)
turns each write into an `auditLog` entry naming the staff member and the
fields that changed. Buses, vendors, drivers and templates are never deleted,
only deactivated. A deletion of a location or blackout is logged as "Staff"
because a deletion carries no author.

The GPS link is kept in `busAdmin` so customers, who can read `buses`, cannot
see where a vehicle is. Driver phone numbers are staff-only too; a customer
sees the driver's name from the bus.

**Starting data.** `tools/seed/seed.json` holds the app's sample records.
Load them with:

```bash
node functions/scripts/seed.js        # real project, uses your `firebase login`
```

It only creates documents that do not exist, so running it again never undoes a
staff edit. Regenerate the file from the sample data with
`EXPORT_SEED=1 flutter test test/firestore_codec_test.dart`. Before launch,
replace the samples through the staff screens (or delete them in the console):
the support/WhatsApp numbers are placeholders, and 11 of the 12 package rate
charts are flagged `sampleRates`.

## Availability, holds and bookings (Stage 3-5)

Bookings, payments, ratings and cancellations live in Firestore. The app never
writes a booking: every change is a Cloud Function, because only the server can
see everyone's bookings and decide, atomically, whether a bus is free.

| Function | What it does |
|---|---|
| `searchBuses` | Which buses are free for a trip: active bus and vendor, enough seats, every day the trip touches open, back within the window, no blackout, no overlapping booking. Searches that find nothing are logged in `searchMisses`. |
| `createHold` | Holds a bus in one transaction, serialised per bus by a lock document, so two customers can never hold the same bus. Hold length comes from `config/app`. A customer may hold at most 3 buses at once. |
| `bookingAction` | Staff only: `confirmCost`, `recordAdvance`, `startTrip`, `completeTrip`, `recordBalance`, `reallocate`, `cancel`. Each step is checked against the booking's current stage, a lapsed hold cannot be confirmed, and each writes an audit entry and, for money, a `payments` record. |
| `expireHolds` | Every minute, marks lapsed holds Expired. Availability already ignores a lapsed hold the moment it lapses. |

Rules (`functions/src/availability.ts`) are a port of `lib/data/availability.dart`
(the app keeps its copy for the staff calendar and for demo mode) and are
evaluated in India time. Trips are sent as wall-clock `YYYY-MM-DDTHH:mm`.

A customer reads only their own bookings and payments; staff read all. Ratings
and cancellation requests are created by the customer for their own booking
only. Notifications and reports are still in memory (Stage 6).

Tests: `cd functions && npm test` (availability rules),
`cd rules-tests && npm test` (security rules, 25) and `npm run e2e` (27, in the
emulators: includes eight customers racing for one bus, the full booking
lifecycle, hold expiry, reallocation and cancellation).

## Notifications, cancellations, account deletion, reports (Stage 5-6)

**Notifications.** `functions/src/bookingEvents.ts` turns each booking change
into an in-app notification (`notifications/{eventId}_{uid}`) and an FCM push:
hold created, cost confirmed, confirmed, bus changed, trip started/completed,
settled, hold expiring (5 minutes before) and expired, cancelled, cancellation
declined. Staff are told about new requests, holds about to lapse and
cancellation requests. The document id comes from the triggering event, so a
trigger delivered twice sends one notification. A failed push never blocks the
booking change. Message wording comes from the four staff-editable templates
(`tpl-cost`, `tpl-confirmed`, `tpl-realloc`, `tpl-hold`) using placeholders
`{reference} {route} {bus} {driver} {fare} {advance} {minutes}`; text without a
placeholder falls back to the built-in wording. Phones register under
`users/{uid}/devices/{token}` (Android works now; iPhones need an Apple
Developer account and push entitlements). Email is not built.

**Cancellations.** A customer asks; staff see it in *Cancellation requests* and
either approve (cancel, release the bus, record a refund up to what was paid) or
decline with a note the customer sees. Both are `bookingAction` steps.

**Account deletion** (`deleteAccount`): refused while any booking is in
progress; otherwise bookings are anonymised (name, phone, landmark, link to the
person removed) but kept with their payments; ratings, cancellation requests
and search logs lose their link; profile, recent searches, devices and
notifications are deleted; then the login.

**Reports** are computed in the app from the real bookings, payments, buses,
vendors and failed-search log (`lib/data/reports.dart`, unit-tested), for
today / the last 7 days / the last 30 days.

Tests now: `cd rules-tests && npm test` (29 rules) and `npm run e2e` (39,
including notifications, hold warnings, refunds and account deletion).

## Bus photos

Staff add up to 4 photos per bus on the Add/Edit bus form (camera or gallery).
Cost is driven by download traffic, so the design sends customers as few bytes
as possible, once per phone:

- **Shrunk on the staff phone** (`lib/features/admin/photos/photo_processor.dart`,
  pure Dart in a background isolate): a 1280 px picture (about 150-300 KB) and a
  360 px thumbnail (about 20-40 KB), JPEG, rotated upright, all metadata (including
  the GPS position) removed. No server-side resizing to pay for.
- **Never overwritten:** every upload gets a new file name, and files carry
  `Cache-Control: public, max-age=31536000, immutable`, so a phone keeps one for a
  year and never asks again.
- **Lists use the thumbnail, the bus page uses the full picture**, and the bus page
  only fetches the next picture once the customer starts swiping.
- **Phone cache:** `cached_network_image` with one shared manager
  (`lib/features/shared/bus_photo.dart`): 60 days, at most 200 files; decoded at the
  size shown. Photo URLs live on the bus document, so previously seen buses still
  show their pictures offline.
- **Tidying:** a trigger deletes the files of a photo removed from a bus, and a weekly
  sweep deletes files no bus refers to that are over a day old
  (`functions/src/busPhotos.ts`). Do not set a "delete everything older than N days"
  rule on the functions image registry (it once deleted the functions themselves).
- **Rules:** `storage.rules` lets any signed-in user read; only staff may add or
  delete, only JPEGs under 700 KB with a photo-shaped name, and never over an
  existing file. `buses` documents may hold at most 4 photos.

Tests: `cd rules-tests && npm run test:storage` (9) and `npm run e2e` (44, incl.
cleanup). A bus with no photos shows a neutral bus picture.

## Android release signing

Release builds are signed with a private upload key, never the debug key.

- The keystore is `~/.android-keystores/driveon-charter/upload-keystore.jks`
  (alias `upload`), kept **outside** the project so a clean cannot delete it.
- Its passwords and path are in `android/key.properties`, which is git-ignored.
- **Back both up somewhere safe and private** (a password manager and an
  encrypted copy). If the key is lost, an app already published on Google Play can
  only be updated by asking Play to reset the upload key.
- On a machine without `android/key.properties`, `flutter build apk --release`
  produces an **unsigned** APK that will not install. That is deliberate: it can
  never be mistaken for a real release, and it never falls back to the debug key.
- To set up another machine, copy the keystore there and create `android/key.properties`:

  ```
  storePassword=...
  keyPassword=...
  keyAlias=upload
  storeFile=/absolute/path/to/upload-keystore.jks
  ```
- Check a build: `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`
  should show `CN=Charter Booking, O=DriveOn, C=IN`, not `Android Debug`.
- When the app goes on Google Play, enrol in Play App Signing: Google keeps the
  final signing key and this one is only the upload key.
