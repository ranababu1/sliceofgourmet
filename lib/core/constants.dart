/// Google Sheets signup webhook. Supplied at build time, never hardcoded:
///   --dart-define=SHEETS_WEBHOOK_URL=https://script.google.com/macros/s/.../exec
/// When empty, signup logging is a no-op.
const String kSheetsWebhookUrl = String.fromEnvironment('SHEETS_WEBHOOK_URL');

/// Shared secret sent with every webhook call (JSON body field `secret` and
/// header `X-Webhook-Secret`). Verify it in the Apps Script.
///   --dart-define=SHEETS_WEBHOOK_SECRET=...
const String kSheetsWebhookSecret =
    String.fromEnvironment('SHEETS_WEBHOOK_SECRET');

// TODO(imran): replace with the real, published privacy policy URL before release.
const String kPrivacyPolicyUrl = 'https://sliceofgourmet.com/privacy-policy/';

/// Network timeout for all HTTP calls.
const Duration kHttpTimeout = Duration(seconds: 15);
