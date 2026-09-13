import 'package:biotime_app/core/layout/keyboard_stable_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android keyboard inset does not switch the employees page layout', () {
    expect(
      useShortEmployeesViewport(layoutHeight: 700, keyboardInset: 0),
      isFalse,
    );
    expect(
      useShortEmployeesViewport(layoutHeight: 400, keyboardInset: 300),
      isFalse,
    );
  });

  test('a genuinely short viewport still uses the scrollable layout', () {
    expect(
      useShortEmployeesViewport(layoutHeight: 400, keyboardInset: 0),
      isTrue,
    );
  });
}
