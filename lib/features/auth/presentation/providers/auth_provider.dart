import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:busgo_mobile/core/constants/api_constants.dart';
import 'package:busgo_mobile/features/auth/data/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  late final GoogleSignIn _googleSignIn;
  StreamSubscription<GoogleSignInAccount?>? _googleSignInSubscription;
  
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isGoogleSignInReady = !kIsWeb;
  String? _errorMessage;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isGoogleSignInReady => _isGoogleSignInReady;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null;

  AuthProvider() {
    _googleSignIn = GoogleSignIn(
      clientId: ApiConstants.GOOGLE_CLIENT_ID,
      serverClientId: kIsWeb ? null : ApiConstants.GOOGLE_CLIENT_ID,
      scopes: const ['email', 'profile', 'openid'],
    );

    _googleSignInSubscription = _googleSignIn.onCurrentUserChanged.listen(
      (GoogleSignInAccount? account) {
        if (!kIsWeb || account == null || _token != null || _isLoading) {
          return;
        }
        unawaited(_completeGoogleSignIn(account));
      },
    );

    if (kIsWeb) {
      unawaited(_initializeGoogleSignInWeb());
    }

    unawaited(_loadPersistedData());
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
      final data = response.data;

      if (data != null) {
        final String? extractedToken = data['token'] ?? data['accessToken'] ?? 
            (data['data'] is Map ? data['data']['token'] : null);

        if (extractedToken != null) {
          _token = extractedToken;
          
          final userPayload = data['user'] ?? 
              (data['data'] is Map && (data['data'] as Map).containsKey('user') ? data['data']['user'] : null) ??
              (data['data'] is Map ? data['data'] : null) ?? 
              data['profile'];

          _user = userPayload is Map<String, dynamic> ? userPayload : (userPayload as Map?)?.cast<String, dynamic>();

          // Lưu trữ Token và User cục bộ
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', _token!);
          if (_user != null) {
            await prefs.setString('user', jsonEncode(_user));
          }

          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = data['message'] ?? 'Đăng nhập thất bại.';
        }
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
        final String? extractedToken = data['token'] ?? data['accessToken'] ?? 
            (data['data'] is Map ? data['data']['token'] : null);

        if (extractedToken != null || data['success'] == true) {
          // Tự động đăng nhập nếu API trả về Token luôn sau đăng ký
          if (extractedToken != null) {
            _token = extractedToken;
            
            final userPayload = data['user'] ?? 
                (data['data'] is Map && (data['data'] as Map).containsKey('user') ? data['data']['user'] : null) ??
                (data['data'] is Map ? data['data'] : null) ?? 
                data['profile'];

            _user = userPayload is Map<String, dynamic> ? userPayload : (userPayload as Map?)?.cast<String, dynamic>();

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('token', _token!);
            if (_user != null) {
              await prefs.setString('user', jsonEncode(_user));
            }
          }
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = data['message'] ?? 'Đăng ký thất bại.';
        }
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

  // Luồng Đăng nhập qua Google (Sign In with Google)
  Future<bool> signInWithGoogle() async {
    if (kIsWeb) {
      _errorMessage = 'Vui lòng dùng nút Google trên trang để đăng nhập.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _errorMessage = 'Đăng nhập Google bị hủy.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      return await _verifyGoogleAccount(googleUser);
    } catch (e) {
      _errorMessage = 'Lỗi: ${e.toString().replaceAll('DioException: ', '')}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _verifyGoogleAccount(googleUser);
    } catch (e) {
      _errorMessage = 'Lỗi: ${e.toString().replaceAll('DioException: ', '')}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _verifyGoogleAccount(GoogleSignInAccount googleUser) async {
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final String? idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      _errorMessage = kIsWeb
          ? 'Không lấy được Google ID token. Vui lòng dùng nút Google chính thức và thử lại.'
          : 'Không lấy được Google ID token. Vui lòng kiểm tra Google OAuth serverClientId.';
      return false;
    }

    final response = await _authService.verifyGoogleToken(idToken);
    final data = response.data;

    if (data != null) {
      final String? extractedToken = data['token'] ?? data['accessToken'] ??
          (data['data'] is Map ? data['data']['token'] : null);

      if (extractedToken != null) {
        _token = extractedToken;

        final userPayload = data['user'] ??
            (data['data'] is Map && (data['data'] as Map).containsKey('user') ? data['data']['user'] : null) ??
            (data['data'] is Map ? data['data'] : null) ??
            data['profile'];

        _user = userPayload is Map<String, dynamic> ? userPayload : (userPayload as Map?)?.cast<String, dynamic>();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        if (_user != null) {
          await prefs.setString('user', jsonEncode(_user));
        }

        return true;
      }

      _errorMessage = data['message'] ?? 'Đăng nhập Google thất bại.';
      return false;
    }

    _errorMessage = 'Không có phản hồi từ máy chủ.';
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

  // Luồng Đăng xuất (Logout)
  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {}
    try {
      await _googleSignIn.disconnect();
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
