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
  // Sau khi lấy danh sách rút gọn, tự động fetch chi tiết song song
  // để merge các trường: fromLocation, toLocation, seatNumber, departureTime, plateNumber, companyName
  Future<void> fetchMyTickets({String? status, String? type}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _ticketService.getTickets(status: status, type: type);
      final data = response.data;
      if (data != null && data['tickets'] != null) {
        final List<dynamic> basicTickets = List<dynamic>.from(data['tickets']);

        // Fetch chi tiết song song cho từng vé để lấy fromLocation, toLocation, seatNumber...
        final detailFutures = basicTickets.map((ticket) async {
          final ticketId = int.tryParse(ticket['id']?.toString() ?? '');
          if (ticketId == null || ticketId == 0) return ticket;

          try {
            final detailResponse = await _ticketService.getTicketDetail(ticketId);
            final detailData = detailResponse.data;
            if (detailData != null) {
              final innerData = detailData['data'] ?? detailData;
              final detailTicket = innerData['ticket'] ?? innerData;

              // Merge các trường chi tiết vào vé rút gọn (không ghi đè nếu đã có)
              if (detailTicket is Map) {
                final enrichedTicket = Map<String, dynamic>.from(ticket);
                final fieldsToMerge = [
                  'fromLocation', 'toLocation', 'departureTime',
                  'seatNumber', 'plateNumber', 'type', 'code',
                  'companyName', 'operatorName',
                ];
                for (final field in fieldsToMerge) {
                  if (detailTicket[field] != null && (enrichedTicket[field] == null || enrichedTicket[field].toString().isEmpty)) {
                    enrichedTicket[field] = detailTicket[field];
                  }
                }
                return enrichedTicket;
              }
            }
          } catch (e) {
            print('=== Enrichment failed for ticket $ticketId: $e ===');
          }
          return ticket;
        }).toList();

        _tickets = await Future.wait(detailFutures);
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
      if (data != null) {
        final innerData = data['data'] ?? data;
        _selectedTicket = innerData['ticket'] ?? innerData;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('DioException: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Tìm kiếm vé theo bookingId trong danh sách vé của user (Tránh lỗi HTTP 500 khi gọi chi tiết sai ID)
  Future<dynamic> findTicketByBookingId(int bookingId) async {
    try {
      final response = await _ticketService.getTickets(limit: 50);
      final data = response.data;
      if (data != null && data['tickets'] != null) {
        final List<dynamic> ticketsList = data['tickets'];
        for (final t in ticketsList) {
          final tBookingId = int.tryParse(t['bookingId']?.toString() ?? '');
          final tId = int.tryParse(t['id']?.toString() ?? '');
          if (tBookingId == bookingId || tId == bookingId) {
            return t;
          }
        }
      }
    } catch (e) {
      print('=== findTicketByBookingId Error: $e ===');
    }
    return null;
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
