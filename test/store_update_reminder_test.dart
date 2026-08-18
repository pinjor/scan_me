import 'package:flutter_test/flutter_test.dart';
import 'package:scanme/core/services/store_update_reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('snooze blocks prompt until after remindLater', () async {
    final now = DateTime.utc(2026, 8, 17, 12);
    await StoreUpdateReminder.snooze(
      now: now,
      duration: const Duration(days: 3),
    );
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt('store_update_remind_after_ms')!;
    expect(
      until,
      now.add(const Duration(days: 3)).millisecondsSinceEpoch,
    );
  });

  test('clearSnooze removes key', () async {
    await StoreUpdateReminder.snooze(
      now: DateTime.utc(2026, 1, 1),
      duration: const Duration(days: 1),
    );
    await StoreUpdateReminder.clearSnooze();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('store_update_remind_after_ms'), isFalse);
  });
}
