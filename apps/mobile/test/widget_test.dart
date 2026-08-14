import 'package:flutter_test/flutter_test.dart';
import 'package:route2go/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('design tokens expose a Material3 light theme', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, isNotNull);
    expect(theme.textTheme.headlineLarge, isNotNull);
  });
}
