import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:busgo_mobile/core/api/rating_service.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:busgo_mobile/features/notifications/presentation/providers/notification_provider.dart';

/// Payload truyền vào modal đánh giá chuyến đi.
class ReviewTicketPayload {
  final int ticketId;
  final int tripId;
  final String companyName;
  final String departureLocation;
  final String arrivalLocation;
  final String departureDate;

  const ReviewTicketPayload({
    required this.ticketId,
    required this.tripId,
    required this.companyName,
    required this.departureLocation,
    required this.arrivalLocation,
    required this.departureDate,
  });
}

/// Modal gửi đánh giá chuyến đi (chỉ dùng ở My Tickets).
/// Mở bằng `showReviewTripModal(...)` để khớp Material/scroll behavior.
Future<bool?> showReviewTripModal(
  BuildContext context, {
  required ReviewTicketPayload payload,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReviewTripModal(payload: payload),
  );
}

class ReviewTripModal extends StatefulWidget {
  final ReviewTicketPayload payload;
  const ReviewTripModal({super.key, required this.payload});

  @override
  State<ReviewTripModal> createState() => _ReviewTripModalState();
}

class _ReviewTripModalState extends State<ReviewTripModal> {
  static const Color _primary = Color(0xff006e1c);
  static const Color _primaryLight = Color(0xff4caf50);
  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [_primary, _primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  int _rating = 5;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 5:
        return 'Tuyệt vời!';
      case 4:
        return 'Rất tốt';
      case 3:
        return 'Bình thường';
      case 2:
        return 'Tệ';
      case 1:
        return 'Rất tệ';
      default:
        return 'Chọn số sao';
    }
  }

  Color _ratingColor(int r) {
    switch (r) {
      case 5:
        return Colors.green.shade600;
      case 4:
        return Colors.lightGreen.shade600;
      case 3:
        return Colors.amber.shade700;
      case 2:
        return Colors.orange.shade700;
      case 1:
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  /// Validate phía client trước khi submit.
  String? _validate() {
    if (_rating < 1 || _rating > 5) {
      return 'Vui lòng chọn số sao từ 1 đến 5.';
    }
    final text = _commentCtrl.text.trim();
    if (text.isNotEmpty && text.length < 10) {
      return 'Nhận xét phải để trống hoặc dài tối thiểu 10 ký tự.';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });

    final ratingService = RatingService();
    final notiProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await ratingService.rateTicket(
        tripId: widget.payload.tripId,
        rating: _rating,
        comment: _commentCtrl.text,
      );

      // Best-effort: tạo notification nội bộ. Không fail toàn bộ flow.
      try {
        final uid = authProvider.userId;
        if (uid != null) {
          await notiProvider.pushUserNotification(
            userId: uid,
            title: 'Cảm ơn bạn đã gửi đánh giá!',
            body:
                'Đóng góp của bạn giúp chuyến xe #${widget.payload.tripId} cải thiện chất lượng dịch vụ.',
            data: '{"path":"/my-tickets"}',
          );
        }
      } catch (_) {}

      // Invalidate cache để list rating refresh ngay.
      // (Không biết trực tiếp companyId ở đây, app tự gọi lại khi mở modal review.)

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã gửi đánh giá!'),
          backgroundColor: _primary,
        ),
      );
    } catch (e) {
      String msg = 'Đã xảy ra lỗi khi gửi đánh giá. Vui lòng thử lại.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          final m = data['message'] ?? data['error'];
          if (m != null && m.toString().isNotEmpty) {
            msg = m.toString();
          }
        }
      }
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          gradient: _primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.rate_review_outlined,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Đánh giá chuyến đi',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                      Semantics(
                        label: 'Đóng',
                        child: IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: Colors.grey.shade600),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Trip info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primary.withOpacity(0.06),
                          _primaryLight.withOpacity(0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _primary.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.business_outlined,
                                size: 14, color: _primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.payload.companyName,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: _primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${widget.payload.tripId}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.payload.departureLocation,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded,
                                size: 16, color: Colors.grey.shade500),
                            Expanded(
                              child: Text(
                                widget.payload.arrivalLocation,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              widget.payload.departureDate,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Star picker
                  Center(
                    child: Text(
                      _ratingLabel(_rating),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _ratingColor(_rating),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final value = i + 1;
                      final filled = value <= _rating;
                      return Semantics(
                        button: true,
                        label: '$value sao trên 5',
                        child: GestureDetector(
                          onTap: () => setState(() => _rating = value),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedScale(
                            scale: filled ? 1.0 : 0.92,
                            duration: const Duration(milliseconds: 160),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: filled
                                    ? Colors.amber.shade600
                                    : Colors.grey.shade400,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  // Comment textarea
                  TextField(
                    controller: _commentCtrl,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Chất lượng xe, thái độ tài xế, độ đúng giờ...',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _primary, width: 1.4),
                      ),
                      counterStyle: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11),
                    ),
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
                  ),

                  // Helper / error
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                size: 16, color: Colors.red.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Nhận xét tùy chọn. Nếu nhập, hãy viết tối thiểu 10 ký tự.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _submitting ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: _submitting ? null : _submit,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: _submitting ? null : _primaryGradient,
                              color:
                                  _submitting ? Colors.grey.shade400 : null,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _submitting
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: _primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.send_rounded,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Gửi đánh giá',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
