import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _googleLogoAsset = 'assets/icons/google_logo.svg';

Widget buildGoogleLoginButton({
  required bool isLoading,
  required VoidCallback? onPressed,
}) {
  return SizedBox(
    width: 64,
    height: 64,
    child: OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: EdgeInsets.zero,
      ),
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
