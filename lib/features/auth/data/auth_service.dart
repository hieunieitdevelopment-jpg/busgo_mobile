import 'package:dio/dio.dart';
import 'package:busgo_mobile/core/api/api_client.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  // Đăng nhập khách hàng (Khớp với POST /auth/sign-in trên Web)
  Future<Response> signIn(String email, String password) async {
    return await _apiClient.dio.post(
      '/auth/sign-in',
      data: {
        'email': email,
        'password': password,
      },
    );
  }

  // Đăng ký tài khoản khách hàng mới (Khớp 100% với POST /customer/sign-up của Swagger)
  Future<Response> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    return await _apiClient.dio.post(
      '/customer/sign-up',
      data: {
        'fullName': fullName,
        'contactInfo': {
          'email': email,
          'phone': phone,
        },
        'password': password,
      },
    );
  }

  // Lấy thông tin cá nhân khách hàng (Khớp 100% với GET /customer/profile)
  Future<Response> getCustomerProfile() async {
    return await _apiClient.dio.get('/customer/profile');
  }

  // Gửi OTP xác thực thay đổi thông tin liên lạc (Khớp với POST /customer/profile/contact/identity/verify)
  Future<Response> verifyContactIdentity({
    required String field, // 'email' hoặc 'phone'
    required String value,
    required String otp,
  }) async {
    return await _apiClient.dio.post(
      '/customer/profile/contact/identity/verify',
      data: {
        'field': field,
        'value': value,
        'otp': otp,
      },
    );
  }

  // Cập nhật thông tin liên lạc mới (Khớp với PUT /customer/profile/contact)
  Future<Response> updateCustomerContact({
    required String field, // 'email' hoặc 'phone'
    required String value,
    required String otp,
  }) async {
    return await _apiClient.dio.put(
      '/customer/profile/contact',
      data: {
        'field': field,
        'value': value,
        'otp': otp,
      },
    );
  }

  // Đăng xuất tài khoản (Khớp với POST /auth/logout trên Web)
  Future<Response> logout() async {
    return await _apiClient.dio.post('/auth/logout');
  }
}
