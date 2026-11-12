import 'package:duplicate_file_remover/src/duplicate_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatExactBytes adds thousands separators', () {
    expect(formatExactBytes(0), '0 B');
    expect(formatExactBytes(999), '999 B');
    expect(formatExactBytes(1000), '1,000 B');
    expect(formatExactBytes(1153024), '1,153,024 B');
    expect(formatExactBytes(1153100), '1,153,100 B');
  });

  test('sizes that round the same stay distinguishable', () {
    expect(formatBytes(1153024), formatBytes(1153100));
    expect(formatExactBytes(1153024), isNot(formatExactBytes(1153100)));
  });
}
