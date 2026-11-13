import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartattend/core/di/app_dependencies.dart';
import 'package:smartattend/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('SmartAttendApp renders splash screen on startup', (WidgetTester tester) async {
    final deps = AppDependencies.create();
    await tester.pumpWidget(SmartAttendApp(deps: deps));
    // Splash is shown while AuthInitial / AuthLoading.
    await tester.pump();
    expect(find.text('SmartAttend'), findsOneWidget);
  });
}
