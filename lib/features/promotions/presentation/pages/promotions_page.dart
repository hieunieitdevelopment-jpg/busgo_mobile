import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:busgo_mobile/core/api/public_service.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final PublicService _publicService = PublicService();
  List<dynamic> _promotions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _publicService.getPromotions(limit: 100);
      final items = res.data['items'] ?? res.data['promotions'] ?? res.data['data'] ?? [];
      
      if (mounted) {
        setState(() {
          _promotions = items is List ? items : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tải danh sách khuyến mãi. Vui lòng thử lại sau.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Không xác định';
    try {
      final date = DateTime.parse(dateStr.toString()).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Không xác định';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stripeColors = [Colors.green, Colors.orange, Colors.blue, Colors.pink, Colors.purple];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mã giảm giá & Ưu đãi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPromotions,
        child: Column(
          children: [
            // Promo input card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Nhập mã giảm giá...',
                            filled: false,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Áp dụng'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Promotions list area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _fetchPromotions,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _promotions.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.local_offer_outlined, color: Colors.grey.shade400, size: 64),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Chưa có mã khuyến mãi nào',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Vui lòng quay lại sau để cập nhật các ưu đãi mới nhất.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _promotions.length,
                              itemBuilder: (context, index) {
                                final promo = _promotions[index];
                                final code = promo['code'] ?? 'BGO${promo['id'] ?? (index + 1)}';
                                final title = promo['title'] ?? 'Khuyến mãi hot';
                                final desc = promo['content'] ?? promo['description'] ?? 'Ưu đãi đặt vé hấp dẫn nhất';
                                final endDateStr = promo['endDate'];
                                final expiry = 'Hạn dùng: ${_formatDate(endDateStr)}';
                                final Color stripeColor = stripeColors[index % stripeColors.length];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildVoucherCard(
                                    context,
                                    code: code,
                                    title: title,
                                    desc: desc,
                                    expiry: expiry,
                                    stripeColor: stripeColor,
                                    onTap: () => context.push('/promotion-detail', extra: promo),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/my-tickets');
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Tìm kiếm'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'Vé của tôi'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Ưu đãi'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(
    BuildContext context, {
    required String code,
    required String title,
    required String desc,
    required String expiry,
    required Color stripeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: IntrinsicHeight(
        child: Row(
          children: [
            // Left stripe color bar
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined, color: Colors.green, size: 20),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã sao chép mã $code!')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(expiry, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    ),);
  }
}
