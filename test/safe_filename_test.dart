import 'package:flutter_test/flutter_test.dart';
import 'package:scanme/core/storage/document_storage_service.dart';

void main() {
  test('safeFileName keeps unicode letters', () {
    expect(
      DocumentStorageService.safeFileName('চুক্তি 2026'),
      isNot(equals('Scan')),
    );
    expect(
      DocumentStorageService.safeFileName('Lease / agreement?'),
      equals('Lease_agreement'),
    );
  });

  test('safeFileName empty falls back', () {
    final name = DocumentStorageService.safeFileName('   ');
    expect(name.startsWith('Scan_'), isTrue);
  });
}
