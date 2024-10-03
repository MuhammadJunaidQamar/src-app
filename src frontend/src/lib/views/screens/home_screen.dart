import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/widgets/info_widget.dart';
import 'package:src/widgets/side_menu_widget.dart';
import 'package:src/widgets/window_buttons_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _onPageSelected(int index) {
    setState(() {
      Constants.pageIdx = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return SafeArea(
      child: Scaffold(
        endDrawer: (Responsive.isMobile(context) || Constants.pageIdx != 0)
            ? Stack(
                alignment: AlignmentDirectional.topEnd,
                children: [
                  const SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Padding(
                      padding: EdgeInsets.only(top: 56),
                      child: InfoWidget(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ),
                ],
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
        body: Row(
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
              child: Routes.getPage(pages[Constants.pageIdx]),
            ),
          ],
        ),
      ),
    );
  }
}
