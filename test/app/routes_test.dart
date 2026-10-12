import 'package:byebyesleep/alarm/ui/alarm_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('unknown route falls back to alarm list', (tester) async {
    await pumpApp(tester, FakeAlarmPlatform(), initialRoute: '/nope');
    expect(find.byType(AlarmListScreen), findsOneWidget);
  });
}
