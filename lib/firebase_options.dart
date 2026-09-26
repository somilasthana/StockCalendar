import 'package:firebase_core/firebase_core.dart';

/// Placeholder. `flutterfire configure` replaces this file.
///
/// Keep [kFirebaseConfigured] false in `firebase_config.dart` until that
/// command has been run, or the app will try to start Firebase with no keys.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured. Run flutterfire configure, then set '
      'kFirebaseConfigured = true in lib/firebase_config.dart.',
    );
  }
}
