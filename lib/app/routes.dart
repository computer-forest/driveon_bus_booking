/// Top-level destinations. Everything inside a shell keeps using ordinary
/// `Navigator` pushes within that shell's own navigator.
class Routes {
  Routes._();

  static const splash = '/';

  /// Signed-out entry, and the first-sign-in steps (profile, biometric/PIN)
  /// that a signed-in customer finishes before reaching the app.
  static const welcome = '/welcome';
  static const home = '/home';
  static const admin = '/admin';
}
