import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:busgo_mobile/core/api/api_client.dart';

/// Service xử lý đăng nhập bằng Google cho vai trò Customer.
///
/// Flow:
/// 1. Mở popup Google Sign-In native (SDK)
/// 2. User chọn tài khoản Google & đồng ý
/// 3. SDK trả về idToken
/// 4. Gửi idToken lên backend POST /auth/google/verify-token
/// 5. Backend xác thực & trả { token, user }
class GoogleAuthService {
  final ApiClient _apiClient = ApiClient();

  /// Web Client ID từ Google Cloud Console
  static const String _webClientId =
      '335430946794-8mkv3iqd0dvgq208ep9gf6t9hj07lsqc.apps.googleusercontent.com';

  /// Instance GoogleSignIn với scopes cần thiết
  /// Trên Web: chỉ dùng clientId (serverClientId không được hỗ trợ)
  /// Trên Mobile: dùng serverClientId để SDK trả về idToken
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _webClientId,
    scopes: ['email', 'profile'],
  );

  /// Thực hiện đăng nhập Google và gửi token lên backend.
  ///
  /// Throws:
  /// - 'cancelled' nếu user hủy đăng nhập
  /// - 'no_token' nếu SDK không trả về idToken
  /// - DioException nếu backend trả lỗi
  Future<Response> signInWithGoogle() async {
    // Bước 1: Mở popup Google Sign-In
    final GoogleSignInAccount? account = await _googleSignIn.signIn();

    // User nhấn Cancel hoặc đóng popup
    if (account == null) {
      throw 'cancelled';
    }

    // Bước 2: Lấy authentication tokens từ Google
    final GoogleSignInAuthentication googleAuth = await account.authentication;
    final String? idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw 'no_token';
    }

    // Bước 3: Gửi idToken lên backend để xác thực
    return await _apiClient.dio.post(
      '/auth/google/verify-token',
      data: {
        'idToken': idToken,
      },
    );
  }

  /// Đăng xuất Google (xóa session cached của SDK)
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
