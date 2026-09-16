import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/views/screens/connection_mode_screen.dart';

void main() {
  setUp(ConnectionConfig.resetSelection);
  tearDown(ConnectionConfig.resetSelection);

  testWidgets('center info is always available and follows protocol accent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          extensions: const [AppThemeColors.dark],
        ),
        home: const ConnectionModeScreen(),
      ),
    );

    final infoButtonFinder = find.widgetWithIcon(
      IconButton,
      Icons.info_outline_rounded,
    );
    expect(
      tester.widget<IconButton>(infoButtonFinder).onPressed,
      isNotNull,
    );

    await tester.tap(infoButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Electrical Engineering Department'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.byIcon(Icons.rocket_launch_outlined),
          )
          .color,
      AppThemeColors.dark.positive,
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(
        ConnectionConfig.modeTitle(ConnectionMode.bleGroundStation),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<IconButton>(infoButtonFinder).onPressed,
      isNotNull,
    );

    await tester.tap(infoButtonFinder);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Icon>(
            find.byIcon(Icons.rocket_launch_outlined),
          )
          .color,
      AppColors.tropicalIndigoColor,
    );
    expect(find.text('Faculty of Engineering'), findsOneWidget);
    expect(find.text('University of Central Punjab'), findsOneWidget);
    expect(find.text('kamran.saleem@ucp.edu.pk'), findsOneWidget);
    expect(find.text('Project Gallery'), findsNothing);
  });
}
