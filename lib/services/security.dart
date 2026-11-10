import 'package:local_auth/local_auth.dart';
import '../core/app_state.dart';

final LocalAuthentication _auth = LocalAuthentication();

// Returns true when the user may enter the app.
// If the phone has no lock screen set, the app opens without asking.
Future<bool> unlockDevice() async {
  try {
    final supported = await _auth.isDeviceSupported();
    if (!supported) return true;
    return await _auth.authenticate(
      localizedReason: appState.t('Unlock A.Jami SOS', 'افتح A.Jami SOS'),
      options: const AuthenticationOptions(stickyAuth: true),
    );
  } catch (_) {
    return false;
  }
}
