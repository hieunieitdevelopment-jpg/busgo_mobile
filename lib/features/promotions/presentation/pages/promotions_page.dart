import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PromotionsPage extends StatelessWidget {
  const PromotionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mã giảm giá & Ưu đãi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Column(
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

          // Filter scroll
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryPill('Tất cả', true),
                _buildCategoryPill('Vé xe khách', false),
                _buildCategoryPill('Thanh toán', false),
                _buildCategoryPill('Mới nhất', false),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Promotions list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildVoucherCard(
                  context,
                  code: 'GIAM50K',
                  title: 'Giảm ngay 50.000đ cho chuyến đầu tiên',
                  expiry: 'Hạn dùng: 31/05/2026',
                  stripeColor: Colors.green,
                ),
                const SizedBox(height: 12),
                _buildVoucherCard(
                  context,
                  code: 'STRIPE20',
                  title: 'Giảm 20% khi thanh toán qua thẻ Visa/Mastercard',
                  expiry: 'Hạn dùng: 31/05/2026',
                  stripeColor: Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildVoucherCard(
                  context,
                  code: 'SUMMER30',
                  title: 'Đón hè rực rỡ - Giảm 30.000đ đi Sa Pa',
                  expiry: 'Hạn dùng: 30/06/2026',
                  stripeColor: Colors.grey,
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildCategoryPill(String title, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.black87,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildVoucherCard(
    BuildContext context, {
    required String code,
    required String title,
    required String expiry,
    required Color stripeColor,
  }) {
    return Card(
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
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(expiry, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            ),

            // Copy button
            IconButton(
              icon: const Icon(Icons.copy_outlined, color: Colors.green),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã sao chép mã $code!')),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
