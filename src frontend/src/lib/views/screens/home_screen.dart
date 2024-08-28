import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/widgets/dashboard_widget.dart';
import 'package:src/widgets/info_wiget.dart';
import 'package:src/widgets/side_menu_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int pageIdx = 0;

  void _onPageSelected(int index) {
    setState(() {
      pageIdx = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      endDrawer: Responsive.isMobile(context)
          ? SizedBox(
              width: 250,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: InfoWidget(),
              ),
            )
          : null,
      drawer: !isDesktop
          ? SizedBox(
              width: 250,
              child: SideMenuWidget(
                onPageSelected: _onPageSelected,
              ),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop)
              Expanded(
                flex: 2,
                child: SideMenuWidget(
                  onPageSelected: _onPageSelected,
                ),
              ),
            Expanded(
              flex: 10,
              child: pages[pageIdx],
            ),
          ],
        ),
      ),
    );
  }
}
