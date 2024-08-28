import 'package:flutter/material.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/widgets/dashboard_widget.dart';
import 'package:src/widgets/info_wiget.dart';
import 'package:src/widgets/side_menu_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: DashboardWidget(),
          ),
          if (isDesktop)
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: InfoWidget(),
              ),
            ),
          // if (Responsive.isTablet(context))
          //   SingleChildScrollView(
          //     scrollDirection: Axis.vertical,
          //     child: Column(
          //       children: [
          //         DashboardWidget(),
          //         SizedBox(height: 18),
          //         InfoWidget(),
          //       ],
          //     ),
          //   ),
        ],
      ),
    );
  }
}
