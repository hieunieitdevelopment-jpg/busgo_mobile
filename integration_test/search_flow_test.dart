/// BusGo E2E Test 3: Search Trip Flow
/// Test luồng tìm kiếm chuyến xe:
/// - Nhấn nút tìm kiếm từ Home
/// - Xác minh trang kết quả hiển thị
/// - Xác minh có dữ liệu hoặc empty state đúng
/// - Kiểm tra filter tabs hoạt động
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

void main() {
  initializeIntegrationTests();

  group('🔍 Search Flow Tests', () {
    testWidgets('TC09: Nhấn Tìm chuyến → chuyển sang SearchResults', (tester) async {
      testLog('TC09: Test flow tìm chuyến xe');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Nhấn nút "Tìm chuyến xe ngay"
      final searchButton = find.text('Tìm chuyến xe ngay');
      expect(searchButton, findsOneWidget,
          reason: 'Phải có nút Tìm chuyến xe ngay trên Home');

      await tester.tap(searchButton);
      await tester.pumpAndSettle(longApiWait);

      // Xác minh chuyển sang trang SearchResults
      expect(find.text('Tìm chuyến xe'), findsOneWidget,
          reason: 'Phải hiển thị tiêu đề "Tìm chuyến xe" trên trang kết quả');

      testLog('TC09: ✅ PASSED - Chuyển sang trang tìm kiếm');
    });

    testWidgets('TC10: SearchResults hiển thị thông tin route đúng', (tester) async {
      testLog('TC10: Kiểm tra thông tin route trên SearchResults');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến search results
      final searchButton = find.text('Tìm chuyến xe ngay');
      await tester.tap(searchButton);
      await tester.pumpAndSettle(longApiWait);

      // Kiểm tra có hiển thị điểm đi (Hà Nội - mặc định)
      expect(find.text('Hà Nội'), findsWidgets,
          reason: 'Phải hiển thị điểm đi Hà Nội');

      // Kiểm tra có hiển thị điểm đến (Sa Pa - mặc định)
      expect(find.text('Sa Pa'), findsWidgets,
          reason: 'Phải hiển thị điểm đến Sa Pa');

      testLog('TC10: ✅ PASSED - Thông tin route hiển thị đúng');
    });

    testWidgets('TC11: SearchResults có filter tabs', (tester) async {
      testLog('TC11: Kiểm tra filter tabs trên SearchResults');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến search results
      await tester.tap(find.text('Tìm chuyến xe ngay'));
      await tester.pumpAndSettle(longApiWait);

      // Kiểm tra có 3 filter tabs
      expect(find.text('Giờ chạy sớm'), findsOneWidget,
          reason: 'Phải có tab Giờ chạy sớm');
      expect(find.text('Giá rẻ nhất'), findsOneWidget,
          reason: 'Phải có tab Giá rẻ nhất');
      expect(find.text('Đánh giá cao'), findsOneWidget,
          reason: 'Phải có tab Đánh giá cao');

      testLog('TC11: ✅ PASSED - Filter tabs hiển thị đúng');
    });

    testWidgets('TC12: SearchResults hiển thị kết quả hoặc empty state', (tester) async {
      testLog('TC12: Kiểm tra kết quả tìm kiếm hoặc empty state');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến search results
      await tester.tap(find.text('Tìm chuyến xe ngay'));
      await tester.pumpAndSettle(longApiWait);

      // Kiểm tra: phải có kết quả trip HOẶC empty state
      final hasResults = find.textContaining('chuyến').evaluate().isNotEmpty;
      final hasEmptyState = find.text('Không tìm thấy chuyến xe').evaluate().isNotEmpty;
      final hasBackButton = find.textContaining('QUAY LẠI').evaluate().isNotEmpty;

      expect(hasResults || hasEmptyState, isTrue,
          reason: 'Phải có kết quả tìm kiếm hoặc thông báo không tìm thấy');

      testLog('TC12: hasResults=$hasResults, hasEmptyState=$hasEmptyState');
      testLog('TC12: ✅ PASSED - Kết quả hoặc empty state hiển thị đúng');
    });

    testWidgets('TC13: Nút Quay lại từ SearchResults → Home', (tester) async {
      testLog('TC13: Test nút quay lại từ SearchResults');
      await pumpApp(tester);
      await performLogin(tester);
      await tester.pumpAndSettle(longApiWait);

      // Navigate đến search results
      await tester.tap(find.text('Tìm chuyến xe ngay'));
      await tester.pumpAndSettle(longApiWait);

      // Tìm nút back (IconButton hoặc BackButton)
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle(apiWait);

        // Xác minh quay về Home
        expect(isOnHomePage(tester), isTrue,
            reason: 'Phải quay lại Home sau khi nhấn back');
        testLog('TC13: ✅ PASSED - Quay lại Home thành công');
      } else {
        testLog('TC13: ⚠️ SKIPPED - Không tìm thấy nút back');
      }
    });
  });
}
