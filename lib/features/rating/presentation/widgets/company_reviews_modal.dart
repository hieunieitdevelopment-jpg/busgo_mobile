import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:busgo_mobile/core/api/rating_service.dart';

/// Mở modal xem đánh giá nhà xe (DraggableScrollableSheet để cảm giác native).
Future<void> showCompanyReviewsModal(
  BuildContext context, {
  required int companyId,
  required String companyName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CompanyReviewsModal(
      companyId: companyId,
      companyName: companyName,
    ),
  );
}

class CompanyReviewsModal extends StatefulWidget {
  final int companyId;
  final String companyName;
  const CompanyReviewsModal({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<CompanyReviewsModal> createState() => _CompanyReviewsModalState();
}

class _CompanyReviewsModalState extends State<CompanyReviewsModal> {
  static const Color _primary = Color(0xff006e1c);
  static const Color _primaryLight = Color(0xff4caf50);
  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [_primary, _primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final RatingService _service = RatingService();

  final List<RatingComment> _comments = [];
  String? _next;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  /// 0 = "Tất cả", 1..5 = lọc theo sao.
  int _starFilter = 0;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  Future<void> _fetch({bool reset = false, bool loadMore = false}) async {
    if (loadMore && _next == null) return;
    setState(() {
      if (reset) {
        _comments.clear();
        _next = null;
        _error = null;
        _loading = true;
      } else if (loadMore) {
        _loadingMore = true;
      }
    });

    try {
      final page = await _service.getTripScheduleRatings(
        companyId: widget.companyId,
        limit: 10,
        star: _starFilter == 0 ? null : _starFilter,
        next: loadMore ? _next : null,
      );
      if (!mounted) return;
      setState(() {
        _comments.addAll(page.comments);
        _next = page.next;
      });
    } catch (e) {
      String msg = 'Không thể tải đánh giá. Vui lòng thử lại.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          final m = data['message'] ?? data['error'];
          if (m != null && m.toString().isNotEmpty) msg = m.toString();
        }
      }
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  /// Tóm tắt từ list đã load (best-effort theo spec).
  double get _avg {
    if (_comments.isEmpty) return 0;
    final sum = _comments.fold<int>(0, (a, c) => a + c.rating);
    return sum / _comments.length;
  }

  /// Map: 5..1 -> count
  Map<int, int> get _distribution {
    final m = {for (int i = 1; i <= 5; i++) i: 0};
    for (final c in _comments) {
      final r = c.rating.clamp(1, 5);
      m[r] = (m[r] ?? 0) + 1;
    }
    return m;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle + header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: _primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.reviews_outlined,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Đánh giá nhà xe',
                                style: TextStyle(
                                  color: _primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.companyName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E1E1E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
                  ],
                ),
              ),
              Expanded(
                child: _buildContent(scrollCtrl),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollCtrl) {
    if (_loading && _comments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primary),
        ),
      );
    }

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (_error != null) _buildErrorBanner(),
        _buildOverviewCard(),
        const SizedBox(height: 16),
        _buildDistribution(),
        const SizedBox(height: 16),
        _buildFilterChips(),
        const SizedBox(height: 12),
        if (_comments.isEmpty && !_loading) _buildEmptyState(),
        ..._comments.map(_buildReviewItem),
        if (_next != null) _buildLoadMoreBtn(),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_primary),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Sections ----------

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade600),
          const SizedBox(width: 8),
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
          TextButton(
            onPressed: () => _fetch(reset: true),
            child: const Text('Thử lại',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    final avgStr = _avg > 0 ? _avg.toStringAsFixed(1) : '0.0';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                avgStr,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = (i + 1) <= _avg.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 14,
                    color: Colors.amber.shade300,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_comments.length} đánh giá',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _comments.isEmpty
                      ? 'Hãy là người đầu tiên đánh giá nhà xe này.'
                      : 'Tổng hợp từ chuyến đi của khách hàng đã hoàn thành.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistribution() {
    final dist = _distribution;
    final total = _comments.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (int s = 5; s >= 1; s--) _buildDistributionBar(s, dist[s] ?? 0, total),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(int star, int count, int total) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Row(
              children: [
                Text(
                  '$star',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.star_rounded,
                    color: Colors.amber.shade600, size: 12),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.amber.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              total > 0 ? '${(pct * 100).round()}%' : '0%',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('Tất cả', 0),
          for (int s = 5; s >= 1; s--) _buildChip('$s★', s),
        ],
      ),
    );
  }

  Widget _buildChip(String label, int value) {
    final selected = _starFilter == value;
    return GestureDetector(
      onTap: () {
        if (_starFilter == value) return;
        setState(() => _starFilter = value);
        _fetch(reset: true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? _primaryGradient : null,
          color: selected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(RatingComment c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: _primaryGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(c.reviewerName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.reviewerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: Color(0xFF1E1E1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            (i + 1) <= c.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 13,
                            color: Colors.amber.shade600,
                          ),
                        ),
                        if (c.createdAt != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(c.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (c.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              c.comment,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.grey.shade400, size: 38),
          ),
          const SizedBox(height: 12),
          Text(
            _starFilter == 0
                ? 'Chưa có đánh giá nào'
                : 'Không có đánh giá $_starFilter sao',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _starFilter == 0
                ? 'Hãy là người đầu tiên đánh giá nhà xe này.'
                : 'Hãy thử bộ lọc số sao khác.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed:
              _loadingMore ? null : () => _fetch(loadMore: true),
          icon: const Icon(Icons.arrow_downward_rounded, size: 16),
          label: const Text('Xem thêm đánh giá'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          ),
        ),
      ),
    );
  }
}
