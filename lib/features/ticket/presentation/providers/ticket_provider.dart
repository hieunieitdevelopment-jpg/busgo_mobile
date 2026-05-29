import 'package:flutter/material.dart';
import 'package:busgo_mobile/features/ticket/data/ticket_service.dart';

class TicketProvider extends ChangeNotifier {
  final TicketService _ticketService = TicketService();

  List<dynamic> _tickets = [];
  dynamic _selectedTicket;
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get tickets => _tickets;
  dynamic get selectedTicket => _selectedTicket;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Lấy danh sách lịch sử vé của khách hàng
  Future<void> fetchMyTickets({String? status, String? type}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _ticketService.getTickets(status: status, type: type);
      final data = response.data;
      if (data != null && data['tickets'] != null) {
        _tickets = data['tickets'];
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Lấy chi tiết một vé cụ thể
  Future<void> fetchTicketDetail(int ticketId) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedTicket = null;
    notifyListeners();

    try {
      final response = await _ticketService.getTicketDetail(ticketId);
      final data = response.data;
      if (data != null && data['ticket'] != null) {
        _selectedTicket = data['ticket'];
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Thực hiện yêu cầu hủy vé
  Future<bool> cancelBookingTicket(int ticketId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _ticketService.cancelTicket(ticketId);
      if (response.statusCode == 200) {
        // Cập nhật lại trạng thái vé tại máy
        _tickets = _tickets.map((t) {
          if (t['id'] == ticketId) {
            t['status'] = 'cancelled';
          }
          return t;
        }).toList();

        if (_selectedTicket != null && _selectedTicket['id'] == ticketId) {
          _selectedTicket['status'] = 'cancelled';
        }

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

  // Gửi nhận xét và đánh giá sao cho chuyến đi
  Future<bool> submitRating({
    required int tripId,
    required int rating,
    required String comment,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _ticketService.rateTicket(
        tripId: tripId,
        rating: rating,
        comment: comment,
      );
      if (response.statusCode == 200) {
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
