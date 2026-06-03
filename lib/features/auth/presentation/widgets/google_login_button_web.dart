import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

const double _googleButtonSize = 64;
const String _googleLogoAsset = 'assets/icons/google_logo.svg';

Widget buildGoogleLoginButton({
  required bool isLoading,
  required VoidCallback? onPressed,
}) {
  return SizedBox(
    width: _googleButtonSize,
    height: _googleButtonSize,
    child: Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        const IgnorePointer(child: _GoogleButtonFace()),
        if (!isLoading)
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,
              child: Center(
                child: web.renderButton(
                  configuration: web.GSIButtonConfiguration(
                    type: web.GSIButtonType.icon,
                    theme: web.GSIButtonTheme.outline,
                    size: web.GSIButtonSize.large,
                    text: web.GSIButtonText.signinWith,
                    shape: web.GSIButtonShape.rectangular,
                    logoAlignment: web.GSIButtonLogoAlignment.left,
                    minimumWidth: _googleButtonSize,
                    locale: 'vi',
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _GoogleButtonFace extends StatelessWidget {
  const _GoogleButtonFace();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.grey.withOpacity(0.3), width: 1.5),
      ),
      child: Center(
        child: Semantics(
          label: 'Đăng nhập qua Google',
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xffE5E7EB),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              _googleLogoAsset,
              width: 28,
              height: 28,
            ),
          ),
        ),
      ),
    );
  }
}
