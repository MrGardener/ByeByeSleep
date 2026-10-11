import 'package:byebyesleep/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots and shows title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ByeByeSleepApp()));
    expect(find.text('ByeByeSleep'), findsWidgets);
  });
}
