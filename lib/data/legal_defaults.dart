import 'models.dart';

/// Basic Terms & Conditions and Privacy Policy shown until staff save their
/// own wording from the app (Configuration). Deliberately general: it states
/// how the service works without promising figures that staff control.
const Map<LegalKind, List<LegalSection>> legalDefaults = {
  LegalKind.terms: [
    LegalSection(
      heading: 'About the service',
      body:
          'This app lets you request a whole bus or tempo traveller on charter for a trip. '
          'It is not a seat-by-seat ticket service. By using the app you agree to these terms.',
    ),
    LegalSection(
      heading: 'Holds and confirmation',
      body:
          'Searching shows buses that look available. Placing a hold reserves the bus for you for a short time '
          'while our team checks the trip and confirms the fare with you. A hold is not a confirmed booking. '
          'A booking is confirmed only after we confirm it and the advance is received.',
    ),
    LegalSection(
      heading: 'Fares and payment',
      body:
          'The fare is confirmed by our team and shown in the app. An advance is due to confirm the booking and the '
          'balance is due as agreed with you. Tolls, parking, state taxes and driver allowances are included only if '
          'they are listed on your fare.',
    ),
    LegalSection(
      heading: 'Cancellations and refunds',
      body:
          'You can ask to cancel a booking from the app. Our team reviews each request and any refund depends on '
          'how close the trip is, as agreed when the booking was confirmed. Refunds are returned to the original payment method.',
    ),
    LegalSection(
      heading: 'Changes to your bus',
      body:
          'If your bus becomes unavailable we may move your booking to another bus of the same or better kind and '
          'tell you straight away. If the fare changes you will be told the reason, and you may cancel if you do not agree.',
    ),
    LegalSection(
      heading: 'Your responsibilities',
      body:
          'Give correct trip details, treat the bus and driver with respect, and do not carry unlawful or hazardous goods. '
          'You are responsible for damage to the bus caused by you or your group.',
    ),
    LegalSection(
      heading: 'Liability',
      body:
          'We take reasonable care in arranging your trip. We are not liable for delays caused by traffic, weather, '
          'road closures or other events outside our control, to the extent the law allows.',
    ),
    LegalSection(
      heading: 'Contact',
      body:
          'For help with a booking, use Call or WhatsApp from Help & support in the Profile tab.',
    ),
  ],
  LegalKind.privacy: [
    LegalSection(
      heading: 'What we collect',
      body:
          'Your mobile number, your name and email if you give them, your trip details and bookings, ratings you submit, '
          'and a device token so we can send notifications to your phone.',
    ),
    LegalSection(
      heading: 'Why we use it',
      body:
          'To sign you in, find and hold buses, confirm and manage your bookings, send you updates about them, '
          'and improve the service. We do not sell your information.',
    ),
    LegalSection(
      heading: 'Who sees it',
      body:
          'Our staff see your name, number and bookings so they can run your trip. The driver is given only what is '
          'needed for the trip. We use Google Firebase and an SMS provider to store data and send sign-in codes.',
    ),
    LegalSection(
      heading: 'Notifications',
      body:
          'We send booking updates to your phone. You can switch off optional alerts under Profile > Notification preferences.',
    ),
    LegalSection(
      heading: 'Your choices',
      body:
          'You can edit your name and email from your profile. You can delete your account from the profile at any time; '
          'your personal details are then removed and your past bookings are kept without your name or number for our records.',
    ),
    LegalSection(
      heading: 'Security',
      body:
          'Your data is held on secured servers and is visible only to you and our staff. No system is perfectly secure, '
          'so please keep your phone locked.',
    ),
    LegalSection(
      heading: 'Contact',
      body:
          'For any privacy question, use Call or WhatsApp from Help & support in the Profile tab.',
    ),
  ],
};
