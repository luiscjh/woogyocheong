import 'package:church_youth_app/services/cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('앱은 규칙(90일)보다 하루 더 지난 알림만 지운다', () {
    final now = DateTime(2026, 11, 22, 12);
    expect(CleanupService.isExpiredNotification(now.subtract(const Duration(days: 92)), now), isTrue);
    expect(CleanupService.isExpiredNotification(now.subtract(const Duration(days: 90, hours: 12)), now), isFalse);
    expect(CleanupService.isExpiredNotification(now.subtract(const Duration(days: 30)), now), isFalse);
  });
}
