import 'package:dio/dio.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:busgo_mobile/core/api/api_client.dart';

/// Service xử lý đăng nhập bằng Facebook cho vai trò Customer.
///
/// Flow:
/// 1. Mở popup Facebook Login (SDK)
/// 2. User đăng nhập Facebook & cấp quyền
/// 3. SDK trả về accessToken
/// 4. Gửi accessToken lên backend POST /auth/facebook/verify-token
/// 5. Backend xác thực & trả { token, user }
class FacebookAuthService {
  final ApiClient _apiClient = ApiClient();

  /// Thực hiện đăng nhập Facebook và gửi token lên backend.
  ///
  /// Throws:
  /// - 'cancelled' nếu user hủy đăng nhập
  /// - 'no_token' nếu SDK không trả về accessToken
  /// - DioException nếu backend trả lỗi
  Future<Response> signInWithFacebook() async {
    // Bước 1: Mở popup Facebook Login với permissions cần thiết
    final LoginResult result = await FacebookAuth.instance.login(
      permissions: ['public_profile', 'email'],
    );

    // Kiểm tra kết quả từ SDK
    switch (result.status) {
      case LoginStatus.success:
        break; // Tiếp tục xử lý bên dưới
      case LoginStatus.cancelled:
        throw 'cancelled';
      case LoginStatus.failed:
        throw result.message ?? 'Đăng nhập Facebook thất bại.';
      case LoginStatus.operationInProgress:
        throw 'Đang xử lý đăng nhập, vui lòng đợi.';
    }

    // Bước 2: Lấy access token từ kết quả
    final AccessToken? accessToken = result.accessToken;

    if (accessToken == null) {
      throw 'no_token';
    }

    // Lấy token string (hỗ trợ cả tokenString và token tùy phiên bản)
    final String tokenValue = accessToken.tokenString;

    if (tokenValue.isEmpty) {
      throw 'no_token';
    }

    // Bước 3: Gửi accessToken lên backend để xác thực
    return await _apiClient.dio.post(
      '/auth/facebook/verify-token',
      data: {
        'accessToken': tokenValue,
        'idToken': '', // Backend yêu cầu field này nhưng để trống cho Facebook
      },
    );
  }

  /// Đăng xuất Facebook (xóa session cached của SDK)
  Future<void> signOut() async {
    await FacebookAuth.instance.logOut();
  }
}
