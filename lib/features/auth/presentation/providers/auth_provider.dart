import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:busgo_mobile/core/constants/api_constants.dart';
import 'package:busgo_mobile/features/auth/data/auth_service.dart';
import 'package:busgo_mobile/features/auth/data/facebook_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FacebookAuthService _facebookAuthService = FacebookAuthService();
  late final GoogleSignIn _googleSignIn;
  StreamSubscription<GoogleSignInAccount?>? _googleSignInSubscription;

  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isSocialLoading = false;
  bool _isGoogleSignInReady = !kIsWeb;
  String? _errorMessage;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSocialLoading => _isSocialLoading;
  bool get isGoogleSignInReady => _isGoogleSignInReady;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null;

  /// Lấy ID người dùng hiện tại (hỗ trợ nhiều tên trường khác nhau từ backend).
  int? get userId {
    if (_user == null) return null;
    final raw = _user!['id'] ?? _user!['userId'] ?? _user!['_id'];
    return int.tryParse(raw?.toString() ?? '');
  }

  AuthProvider() {
    _googleSignIn = GoogleSignIn(
      clientId: ApiConstants.GOOGLE_CLIENT_ID,
      serverClientId: kIsWeb ? null : ApiConstants.GOOGLE_CLIENT_ID,
      scopes: const ['email', 'profile', 'openid'],
    );

    _googleSignInSubscription = _googleSignIn.onCurrentUserChanged.listen(
      (GoogleSignInAccount? account) {
        if (!kIsWeb || account == null || _token != null || _isSocialLoading) {
          return;
        }
        unawaited(_completeGoogleSignIn(account));
      },
    );

    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadPersistedData();
    if (kIsWeb) {
      await _initializeGoogleSignInWeb();
    }
  }

  Future<void> _initializeGoogleSignInWeb() async {
    try {
      await _googleSignIn.signInSilently();
    } catch (_) {
      // Silent sign-in may fail when there is no Google session yet.
    } finally {
      _isGoogleSignInReady = true;
      notifyListeners();
    }
  }

  // Tự động nạp Token & Profile từ bộ nhớ khi bật App
  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userStr = prefs.getString('user');
    if (userStr != null) {
      try {
        _user = jsonDecode(userStr);
      } catch (e) {
        _user = null;
      }
    }
    notifyListeners();

    // Nếu đã đăng nhập, tự động tải hồ sơ cá nhân mới nhất từ server
    if (isAuthenticated) {
      unawaited(fetchLatestProfile());
    }
  }

  // Luồng Đăng nhập (Sign In)
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signIn(email, password);
      final result = await _processAuthResponse(response.data);

      if (result) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Luồng Đăng ký (Sign Up) khớp tham số Swagger mới
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signUp(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );
      final data = response.data;

      if (data != null) {
        final String? extractedToken = data['token'] ??
            data['accessToken'] ??
            (data['data'] is Map ? data['data']['token'] : null);

        if (extractedToken != null || data['success'] == true) {
          if (extractedToken != null) {
            await _processAuthResponse(data);
          }
          _isLoading = false;
          notifyListeners();
          return true;
        }

        _errorMessage = data['message'] ?? 'Đăng ký thất bại.';
      } else {
        _errorMessage = 'Không có phản hồi từ máy chủ.';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Tải thông tin cá nhân mới nhất (GET /customer/profile)
  Future<void> fetchLatestProfile() async {
    try {
      final response = await _authService.getCustomerProfile();
      final data = response.data;
      if (data != null) {
        final userPayload = data['user'] ??
            (data['data'] is Map && (data['data'] as Map).containsKey('user') ? data['data']['user'] : null) ??
            (data['data'] is Map ? data['data'] : null) ??
            data['profile'];

        _user = userPayload is Map<String, dynamic> ? userPayload : (userPayload as Map?)?.cast<String, dynamic>();

        if (_user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(_user));
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // Xác thực đổi thông tin liên lạc (POST /customer/profile/contact/identity/verify)
  Future<bool> verifyContact({
    required String field,
    required String value,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.verifyContactIdentity(
        field: field,
        value: value,
        otp: otp,
      );
      final data = response.data;
      if (data != null) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Gửi OTP đến email/SĐT (POST /auth/send-otp)
  Future<bool> sendOtp({
    required String field,
    required String value,
  }) async {
    try {
      await _authService.sendOtp(field: field, value: value);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
      rethrow;
    }
  }

  // Cập nhật thông tin liên lạc mới (PUT /customer/profile/contact)
  Future<bool> updateContact({
    required String field,
    required String value,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.updateCustomerContact(
        field: field,
        value: value,
        otp: otp,
      );
      final data = response.data;
      if (data != null && data['user'] != null) {
        _user = data['user'];
        if (data['token'] != null) {
          _token = data['token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', _token!);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(_user));
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Đăng nhập bằng Google
  Future<bool> signInWithGoogle() async {
    if (kIsWeb) {
      _errorMessage = 'Vui lòng dùng nút Google trên trang để đăng nhập.';
      notifyListeners();
      return false;
    }

    _isSocialLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw 'cancelled';
      }

      return await _verifyGoogleAccount(googleUser);
    } on String catch (code) {
      _errorMessage = _socialErrorMessage(code);
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
      return false;
    } finally {
      _isSocialLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    _isSocialLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _verifyGoogleAccount(googleUser);
    } on String catch (code) {
      _errorMessage = _socialErrorMessage(code);
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
      return false;
    } finally {
      _isSocialLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _verifyGoogleAccount(GoogleSignInAccount googleUser) async {
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final String? idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw 'no_token';
    }

    final response = await _authService.verifyGoogleToken(idToken);
    return await _processAuthResponse(response.data);
  }

  // Đăng nhập bằng Facebook
  Future<bool> signInWithFacebook() async {
    _isSocialLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _facebookAuthService.signInWithFacebook();
      final result = await _processAuthResponse(response.data);

      if (result) {
        _isSocialLoading = false;
        notifyListeners();
        return true;
      }
    } on String catch (code) {
      _errorMessage = _socialErrorMessage(code);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isSocialLoading = false;
    notifyListeners();
    return false;
  }

  // Trích xuất token + user từ response backend.
  Future<bool> _processAuthResponse(dynamic data) async {
    if (data == null) {
      _errorMessage = 'Không có phản hồi từ máy chủ.';
      return false;
    }

    final String? extractedToken = data['token'] ??
        data['accessToken'] ??
        (data['data'] is Map ? data['data']['token'] : null) ??
        (data['data'] is Map ? data['data']['accessToken'] : null);

    if (extractedToken == null || extractedToken.isEmpty) {
      _errorMessage = data['message'] ?? 'Đăng nhập thất bại.';
      return false;
    }

    _token = extractedToken;

    final userPayload = data['user'] ??
        (data['data'] is Map && (data['data'] as Map).containsKey('user') ? data['data']['user'] : null) ??
        (data['data'] is Map ? data['data'] : null) ??
        data['profile'] ??
        {};

    _user = userPayload is Map<String, dynamic> ? userPayload : (userPayload as Map?)?.cast<String, dynamic>() ?? {};

    await _persistAuth();
    return true;
  }

  // Lưu token + user vào local storage
  Future<void> _persistAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    if (_user != null) {
      await prefs.setString('user', jsonEncode(_user));
    }
  }

  // Dịch error code từ social SDK sang thông báo tiếng Việt
  String _socialErrorMessage(String code) {
    switch (code) {
      case 'cancelled':
        return 'Bạn đã hủy đăng nhập.';
      case 'no_token':
        return kIsWeb
            ? 'Không lấy được Google ID token. Vui lòng dùng nút Google chính thức và thử lại.'
            : 'Không lấy được token xác thực. Vui lòng thử lại.';
      default:
        return code;
    }
  }

  // Luồng Đăng xuất (Logout) — bao gồm cả social SDK
  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {}
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    try {
      await _facebookAuthService.signOut();
    } catch (_) {}

    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }

  @override
  void dispose() {
    _googleSignInSubscription?.cancel();
    super.dispose();
  }
}
