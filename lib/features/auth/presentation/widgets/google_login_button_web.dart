import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget buildGoogleLoginButton({
  required bool isLoading,
  required VoidCallback? onPressed,
}) {
  if (isLoading) {
    return const SizedBox(
      width: double.infinity,
      height: 48,
      child: Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff006e1c)),
          ),
        ),
      ),
    );
  }

  return SizedBox(
    width: double.infinity,
    height: 48,
    child: Center(
      child: web.renderButton(
        configuration: web.GSIButtonConfiguration(
          type: web.GSIButtonType.standard,
          theme: web.GSIButtonTheme.outline,
          size: web.GSIButtonSize.large,
          text: web.GSIButtonText.signinWith,
          shape: web.GSIButtonShape.rectangular,
          logoAlignment: web.GSIButtonLogoAlignment.left,
          minimumWidth: 320,
          locale: 'vi',
        ),
      ),
    ),
  );
}
