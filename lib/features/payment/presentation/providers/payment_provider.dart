import 'package:flutter/material.dart';
import 'package:busgo_mobile/features/payment/data/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  List<dynamic> _paymentMethods = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get paymentMethods => _paymentMethods;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Lấy danh sách thẻ liên kết
  Future<void> fetchPaymentMethods() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _paymentService.getPaymentMethods();
      final data = response.data;
      if (data != null && data['paymentMethods'] != null) {
        _paymentMethods = data['paymentMethods'];
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Khởi tạo Setup Intent Client Secret từ Stripe
  Future<String?> generateStripeClientSecret() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _paymentService.createSetupIntent();
      final data = response.data;
      _isLoading = false;
      notifyListeners();
      if (data != null && data['clientSecret'] != null) {
        return data['clientSecret'].toString();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  // Khai báo liên kết thẻ thành công
  Future<bool> linkNewCard(String stripePaymentMethodId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _paymentService.addPaymentMethod(stripePaymentMethodId);
      if (response.statusCode == 200) {
        // Tải lại danh sách thẻ mới
        await fetchPaymentMethods();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Đặt thẻ thanh toán mặc định
  Future<bool> setCardAsDefault(String stripePaymentMethodId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _paymentService.setDefaultPaymentMethod(stripePaymentMethodId);
      if (response.statusCode == 200) {
        _paymentMethods = _paymentMethods.map((card) {
          card['isDefault'] = card['stripePaymentMethodId'] == stripePaymentMethodId;
          return card;
        }).toList();
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

  // Xóa thẻ liên kết
  Future<bool> removeCard(String stripePaymentMethodId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _paymentService.deletePaymentMethod(stripePaymentMethodId);
      if (response.statusCode == 200) {
        _paymentMethods.removeWhere((card) => card['stripePaymentMethodId'] == stripePaymentMethodId);
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
}
