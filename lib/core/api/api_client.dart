import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio dio;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://busgo.servecounterstrike.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Thêm các Interceptors (Bộ lọc gửi và nhận yêu cầu)
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Lấy token từ SharedPreferences (tương tự localStorage trên Web)
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');

          // Các endpoint công khai không cần token
          final publicEndpoints = [
            '/auth/send-otp',
            '/auth/reset-password',
            '/auth/sign-in',
            '/auth/google/verify-token',
            '/auth/facebook/verify-token',
            '/customer/sign-in',
            '/customer/sign-up',
          ];

          final isPublic = publicEndpoints.any((endpoint) => options.path.startsWith(endpoint));

          if (token != null && !isPublic) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          // Dịch lỗi sang tiếng Việt đồng bộ 100% với axiosClient.js
          String errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại.';

          if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
            errorMessage = 'Kết nối quá hạn, vui lòng kiểm tra mạng.';
          } else if (e.type == DioExceptionType.connectionError) {
            errorMessage = 'Lỗi kết nối mạng, vui lòng thử lại sau.';
          } else if (e.response != null) {
            final status = e.response!.statusCode;
            final data = e.response!.data;

            // Xử lý Unauthorized (Phiên đăng nhập hết hạn)
            if (status == 401) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('user');
              errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
            } else if (data is Map && (data.containsKey('message') || data.containsKey('error'))) {
              final rawMsg = data['message'] ?? data['error'];
              errorMessage = _translateError(rawMsg.toString());
            }
          }

          // Tạo một DioException mới chứa thông báo lỗi tiếng Việt thân thiện
          final customException = DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: errorMessage,
          );

          return handler.next(customException);
        },
      ),
    );
  }

  // Hàm dịch lỗi tiếng Việt đồng bộ 100% từ Web
  String _translateError(String msg) {
    final lowerMsg = msg.toLowerCase();
    if (lowerMsg.contains('network error')) return 'Lỗi kết nối mạng, vui lòng thử lại sau.';
    if (lowerMsg.contains('timeout')) return 'Kết nối quá hạn, vui lòng kiểm tra mạng.';
    if (lowerMsg.contains('unauthorized') || lowerMsg.contains('invalid token')) return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.';
    if (lowerMsg.contains('forbidden') || lowerMsg.contains('not allowed')) return 'Bạn không có quyền thực hiện thao tác này.';
    if (lowerMsg.contains('not found')) return 'Không tìm thấy dữ liệu yêu cầu.';
    if (lowerMsg.contains('internal server error')) return 'Lỗi hệ thống máy chủ. Vui lòng thử lại sau.';
    if (lowerMsg.contains('bad request') || lowerMsg.contains('invalid input')) return 'Dữ liệu đầu vào không hợp lệ.';
    if (lowerMsg.contains('already exists')) return 'Dữ liệu đã tồn tại trong hệ thống.';
    if (lowerMsg.contains('invalid credentials') || lowerMsg.contains('wrong password')) return 'Sai tên đăng nhập hoặc mật khẩu.';
    if (lowerMsg.contains('user not found') || lowerMsg.contains('not exist')) return 'Tài khoản không tồn tại.';
    if (lowerMsg.contains('email already in use') || lowerMsg.contains('email exists')) return 'Email này đã được sử dụng.';
    if (lowerMsg.contains('validation failed')) return 'Dữ liệu không đúng định dạng.';
    if (lowerMsg.contains('not enough seats') || lowerMsg.contains('seat unavailable') || lowerMsg.contains('already booked')) return 'Ghế này đã có người đặt, vui lòng chọn ghế khác.';
    if (lowerMsg.contains('invalid coupon') || lowerMsg.contains('coupon expired') || lowerMsg.contains('not valid')) return 'Mã khuyến mãi không hợp lệ hoặc đã hết hạn.';
    return msg;
  }
}
