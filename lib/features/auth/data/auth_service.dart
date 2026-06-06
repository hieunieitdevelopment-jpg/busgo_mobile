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

  // Đăng nhập qua Google (Khớp với POST /auth/google/verify-token)
  Future<Response> verifyGoogleToken(String idToken) async {
    return await _apiClient.dio.post(
      '/auth/google/verify-token',
      data: {
        'idToken': idToken,
      },
    );
  }

  // Gửi OTP đến email/SĐT — POST /auth/send-otp
  // Dùng cho 2 luồng: (1) verify giá trị hiện tại, (2) gửi OTP đến giá trị mới.
  Future<Response> sendOtp({
    required String field, // 'email' | 'phone'
    required String value,
  }) async {
    return await _apiClient.dio.post(
      '/auth/send-otp',
      data: {
        'field': field,
        'value': value,
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
  Future<Response> logout({String? token}) async {
    return await _apiClient.dio.post(
      '/auth/logout',
      options: token == null
          ? null
          : Options(headers: {
              'Authorization': 'Bearer $token',
            }),
    );
  }

  // Gửi email thông báo qua API (POST /auth/email/send)
  Future<Response> sendEmail({
    required String to,
    required String subject,
    required String text,
    String template = 'default',
    Map<String, dynamic>? params,
  }) async {
    return await _apiClient.dio.post(
      '/auth/email/send',
      data: {
        'to': to,
        'subject': subject,
        'text': text,
        'template': template,
        'params': params ?? {},
      },
    );
  }
}
