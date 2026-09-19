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
