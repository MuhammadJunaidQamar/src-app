import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/utils/responsive.dart';
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
      endDrawer: Responsive.isMobile(context) // && pageIdx == 0
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
                  padding: const EdgeInsets.only(top: 24, right: 19),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.cancel_outlined,
                    ),
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
