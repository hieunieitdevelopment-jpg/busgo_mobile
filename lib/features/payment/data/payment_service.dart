import 'package:dio/dio.dart';
import 'package:busgo_mobile/core/api/api_client.dart';

class PaymentService {
  final ApiClient _apiClient = ApiClient();

  // Lấy Client Secret để thiết lập liên kết thẻ thanh toán (Khớp với POST /customer/payment-methods/setup-intent)
  Future<Response> createSetupIntent() async {
    return await _apiClient.dio.post('/customer/payment-methods/setup-intent');
  }

  // Khai báo liên kết thẻ thanh toán mới (Khớp với POST /customer/payment-methods)
  Future<Response> addPaymentMethod(String paymentMethodId) async {
    return await _apiClient.dio.post(
      '/customer/payment-methods',
      data: {
        'paymentMethodId': paymentMethodId,
      },
    );
  }

  // Lấy danh sách thẻ thanh toán đã liên kết của user (Khớp với GET /customer/payment-methods)
  Future<Response> getPaymentMethods() async {
    return await _apiClient.dio.get('/customer/payment-methods');
  }

  // Cài đặt thẻ thanh toán mặc định (Khớp với PUT /customer/payment-methods/default)
  Future<Response> setDefaultPaymentMethod(String paymentMethodId) async {
    return await _apiClient.dio.put(
      '/customer/payment-methods/default',
      data: {
        'paymentMethodId': paymentMethodId,
      },
    );
  }

  // Xóa thẻ thanh toán đã liên kết (Khớp với DELETE /customer/payment-methods)
  Future<Response> deletePaymentMethod(String paymentMethodId) async {
    return await _apiClient.dio.delete(
      '/customer/payment-methods',
      data: {
        'paymentMethodId': paymentMethodId,
      },
    );
  }
}
