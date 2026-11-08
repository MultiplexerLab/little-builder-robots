/// External links in the Grown-ups area, opened only behind the Parent gate
/// (PAR-06, PRV-04).
///
/// Placeholders: set the real privacy policy URL (PRV-07) and support
/// address before the first TestFlight build.
abstract final class AppLinks {
  static final Uri privacyPolicy = Uri.parse(
    'https://example.com/little-builder-robots/privacy',
  );
  static final Uri supportEmail = Uri(
    scheme: 'mailto',
    path: 'support@example.com',
    query: 'subject=Little%20Builder%20Robots',
  );
}
