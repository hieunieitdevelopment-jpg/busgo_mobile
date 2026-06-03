import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util';

class GoogleSignInWeb {
  static const String clientId = "335430946794-8mkv3iqd0dvgq208ep9gf6t9hj07lsqc.apps.googleusercontent.com";
  static String? _idToken;

  static Future<String?> getIdToken() async {
    try {
      // Initialize Google ID Services
      final config = jsify({
        'client_id': clientId,
        'callback': allowInterop(_handleGoogleSignIn),
      });

      js.context.callMethod('google.accounts.id.initialize', [config]);

      // Render the button
      final buttonElement = html.document.getElementById('google_signin_button');
      if (buttonElement != null) {
        final buttonConfig = jsify({
          'type': 'standard',
          'size': 'large',
          'theme': 'outline',
          'text': 'signin_with',
        });
        js.context.callMethod('google.accounts.id.renderButton', [buttonElement, buttonConfig]);
      }

      // Show the One Tap UI
      final oneTapConfig = jsify({
        'cancel_on_tap_outside': true,
      });
      js.context.callMethod('google.accounts.id.prompt', [oneTapConfig]);

      // Wait for token with timeout
      return await Future.delayed(const Duration(milliseconds: 500)).then((_) {
        return _idToken;
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () => _idToken,
      );
    } catch (e) {
      print('Error in Google Sign-In Web: $e');
      return null;
    }
  }

  static void _handleGoogleSignIn(dynamic response) {
    if (response is js.JsObject) {
      _idToken = response['credential'] as String?;
    }
  }
}
