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

The app still uses the on-device stand-in for sign-in unless you build with
`--dart-define=USE_FIREBASE=true`. Turn that on once the functions are
deployed (needs the Blaze plan).

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

**Create the first staff account** (it cannot come from the app):

```bash
cd functions
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 npm run create-admin -- you@example.com "Your Name" 'password'
```

For the real project, point `GOOGLE_APPLICATION_CREDENTIALS` at a service
account key instead, and delete the key afterwards.
