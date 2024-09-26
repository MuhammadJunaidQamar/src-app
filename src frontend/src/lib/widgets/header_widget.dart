import 'package:flutter/material.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/widgets/custom_card_widget.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!Responsive.isDesktop(context))
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(
                Icons.menu,
                color: Colors.grey,
                size: 25,
              ),
            ),
          ),
        Expanded(
          child: CustomCard(
            child: Text(AppText.appName),
          ),
        ),
        if (Responsive.isMobile(context))
          IconButton(
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: const Icon(
              Icons.insert_chart_outlined_sharp,
              color: Colors.grey,
              size: 25,
            ),
          ),
      ],
    );
  }
}
