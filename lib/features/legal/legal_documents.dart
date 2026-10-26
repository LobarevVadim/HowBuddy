class LegalSection {
  const LegalSection(this.heading, this.paragraphs);

  final String heading;
  final List<String> paragraphs;
}

class LegalDocument {
  const LegalDocument({required this.title, required this.sections});

  final String title;
  final List<LegalSection> sections;
}

const legalDocuments = <LegalDocument>[
  LegalDocument(
    title: 'Terms and Conditions',
    sections: [
      LegalSection('Who operates HowBuddy', [
        'HowBuddy is an educational service operated under the HowBuddy name. Questions about these terms or the service can be sent to hello@howbuddy.app. These terms take effect on October 26, 2026.',
      ]),
      LegalSection('Using the service', [
        'You may use HowBuddy to learn about human biology, track your learning, and use optional features such as Bobo AI. Keep your sign-in details private, provide accurate account information, and do not use the service to break the law, interfere with the service, or access another person’s account.',
        'You are responsible for activity performed through your account. Contact hello@howbuddy.app promptly if you believe someone has accessed it without permission.',
      ]),
      LegalSection('Age and children', [
        'HowBuddy asks for an age in account preferences, but that age is self-reported and is not verified. HowBuddy does not currently provide a verified parental-consent process. A parent or guardian should not create an account for a child under 13 through the current flow. This limitation is not a substitute for age-assurance or parental-consent controls where the law requires them.',
      ]),
      LegalSection('Learning and AI limits', [
        'HowBuddy and Bobo provide general educational information, not medical diagnosis, treatment, or emergency advice. Do not use them in place of a clinician. For urgent symptoms, contact local emergency services or a qualified health professional.',
        'AI responses can be incomplete or wrong. Check important health information with a qualified professional or reliable source. Do not enter personal medical details or other sensitive information into Bobo.',
      ]),
      LegalSection('Virtual rewards', [
        'Hearts, emeralds, experience points, streaks, freezes, and XP boosts are in-app features. They have no cash value, cannot be transferred, and are not currently sold for money. We may change or remove virtual rewards as the service evolves, subject to rights that cannot be excluded by law.',
      ]),
      LegalSection('Availability and changes', [
        'We work to keep HowBuddy available, but do not promise uninterrupted or error-free service. We may update these terms when the service or law changes. If an update materially affects users, we will show the new version and request acceptance where required.',
      ]),
      LegalSection('Local rights and contact', [
        'Mandatory consumer and privacy rights in your place of residence continue to apply. Nothing in these terms removes a right that cannot legally be waived. Contact hello@howbuddy.app with questions or complaints.',
      ]),
    ],
  ),
  LegalDocument(
    title: 'Privacy Policy',
    sections: [
      LegalSection('Who is responsible', [
        'HowBuddy, operated under the HowBuddy name, is responsible for personal information handled through the app. Privacy questions or requests to access, correct, or delete information can be sent to hello@howbuddy.app. This policy is effective October 26, 2026.',
      ]),
      LegalSection('Information we collect', [
        'Account information: name, email address, password hash (never the plain-text password), sign-in provider identifier for Google sign-in, and account creation and last-active times.',
        'Profile and device preferences: age in years as entered by you, language, avatar palette, glasses and emoji, dark-mode preference, device platform and push-notification token if you enable notifications, notification schedule preferences, and time zone.',
        'Learning and rewards: selected topics, lesson completion, exercise attempt details used by Bobo, XP, hearts, emeralds, streak and streak-freeze records, and XP-boost state.',
        'Bobo conversations: the messages you send and Bobo’s replies, linked to your account and lesson so the conversation can continue. Do not send medical histories, symptoms, or other sensitive personal details.',
        'Support email: if you email HowBuddy or write to a support address, we process the sender and recipient addresses, message, headers, attachments, and reply history needed to answer you.',
        'Technical information: hosting, identity, push, and security providers may receive IP address, browser or device details, request metadata, and diagnostic information as part of delivering and securing their services.',
      ]),
      LegalSection('Why we use it', [
        'We use account information to create accounts and sign users in; profile information to apply preferences; learning records to show progress, streaks, and leaderboards; and device tokens and notification preferences to deliver reminders you enable. We use support messages to respond, and limited technical records to operate, troubleshoot, and protect the service.',
        'When you choose to use Bobo, your message, current lesson and exercise context, and a limited recent conversation history are sent to OpenAI to generate a tutoring response. The request is not intentionally sent with your name, email, or account ID. The conversation itself is stored by HowBuddy so you can return to it.',
      ]),
      LegalSection('Service providers and sharing', [
        'Render hosts the API and PostgreSQL database. Google provides Google sign-in, Firebase Cloud Messaging for push notifications, and Google Cloud Translation for lesson text translated by an administrator. The mobile app includes Google Mobile Ads test units; these are test ads, not production ad placements.',
        'OpenAI processes Bobo prompts and lesson context when Bobo is used. Resend sends service email and handles HowBuddy support email, including inbound messages and attachments. Cloudflare provides DNS and may proxy or protect traffic for howbuddy.app. These providers process information under their own terms and privacy practices.',
        'We do not sell personal information. We disclose information to these providers only as needed for their services, and may disclose it when legally required or necessary to protect the service and people. Providers may process information in countries other than yours; the exact Render database region is controlled in the Render dashboard and is not specified in this repository.',
      ]),
      LegalSection('Analytics, advertising, and email', [
        'The Flutter source currently contains no Firebase Analytics package or analytics calls. A Firebase measurement ID is configured, but the app does not currently use it for product analytics. Rewarded ads are simulated on web and use AdMob test ad units on mobile; they do not generate ad revenue. Replace test configuration and update this policy before serving production ads or enabling analytics.',
        'The current notification-email code is restricted to the owner’s test email address. Support replies and inbound support handling may still use Resend. Update this notice if that test restriction is removed or email practices change.',
      ]),
      LegalSection('Retention and your choices', [
        'Account, learning, and Bobo records remain in the database while the account is active. The app does not yet have a self-service account deletion control or a published automatic deletion schedule. Email hello@howbuddy.app to request access, correction, or deletion. We will verify the request and handle it under applicable law; limited records may remain where required for security, legal obligations, or backups until those copies expire.',
        'You can change profile and notification settings in the app and can disable notifications through your device or browser. You may stop using Bobo at any time. You can withdraw optional notification permission in app settings or device settings.',
      ]),
      LegalSection('Children, security, and changes', [
        'The app currently asks for a self-reported age only after account creation and permits ages from 1 to 120. It does not verify age or obtain verifiable parental consent. This is a material limitation: do not use the current account flow for children under 13, and do not launch a child-directed service until an appropriate age and parental-consent process has been reviewed and implemented.',
        'We use measures such as password hashing, authenticated API access, and hosted database controls, but no internet service can promise perfect security. If a privacy incident occurs, we will assess notification and reporting duties under applicable law. We may update this policy as data practices change and will record the version accepted in the app.',
      ]),
    ],
  ),
  LegalDocument(
    title: 'Cookie and Device Storage Policy',
    sections: [
      LegalSection('What this policy covers', [
        'Browsers and mobile apps can store information using cookies, local storage, IndexedDB, service workers, or similar device storage. This policy covers those technologies in HowBuddy, not only browser cookies.',
      ]),
      LegalSection('What HowBuddy currently stores', [
        'The web app stores your selected language and dark-mode preference in browser storage. The sign-in token is held in app memory and is not intentionally persisted by the Flutter client. If you enable web push notifications, Firebase messaging uses a service worker and browser storage to maintain the push subscription and token.',
        'Google sign-in, Cloudflare, Render, or other infrastructure may use their own cookies or similar storage for authentication, security, fraud prevention, or delivery. Their exact behavior depends on their current configuration and policies.',
      ]),
      LegalSection('Consent', [
        'A code review found no analytics calls or production advertising cookies in the current app. The storage described above supports a feature you request, a preference you choose, authentication, or security. Based on that inventory, a separate opt-in cookie banner is not currently added for non-essential tracking because no such tracking is implemented. This is not a legal determination for every country or every future deployment.',
        'If HowBuddy adds analytics, personalized advertising, or other non-essential storage, it must add a separate, withdrawable opt-in choice before that storage runs in jurisdictions that require consent. You can clear browser storage or revoke notification permission in browser settings; clearing storage may reset preferences or push registration.',
      ]),
    ],
  ),
  LegalDocument(
    title: 'Refund Policy',
    sections: [
      LegalSection('Current purchases', [
        'HowBuddy currently does not sell subscriptions, paid lessons, or virtual currency. Emeralds, XP boosts, hearts, and other rewards are earned or used inside the app and have no cash value. There is currently no HowBuddy purchase to refund.',
      ]),
      LegalSection('If paid features are introduced', [
        'Before any paid feature is offered, HowBuddy must publish updated pricing, renewal and cancellation terms, and a refund process. Mandatory refund, withdrawal, and consumer rights in your location will apply even if a future store policy says otherwise. Purchases made through Apple or Google may also be subject to the relevant store’s billing and refund process.',
      ]),
      LegalSection('Questions', [
        'For billing or refund questions, contact hello@howbuddy.app and include the purchase receipt if a future paid purchase has been made. Do not email passwords or full payment-card numbers.',
      ]),
    ],
  ),
];
