import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:busgo_mobile/features/auth/data/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null;

  /// Lấy ID người dùng hiện tại (hỗ trợ nhiều tên trường khác nhau từ backend).
  int? get userId {
    if (_user == null) return null;
    final raw = _user!['id'] ?? _user!['userId'] ?? _user!['_id'];
    return int.tryParse(raw?.toString() ?? '');
  }

  AuthProvider() {
    _loadPersistedData();
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
      fetchLatestProfile();
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

    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }
}
