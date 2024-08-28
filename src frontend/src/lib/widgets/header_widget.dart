import 'package:flutter/material.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/utils/responsive.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!Responsive.isDesktop(context))
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: InkWell(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Icon(
                Icons.menu,
                color: Colors.grey,
                size: 25,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  width: 5,
                  color: Theme.of(context).primaryColor,
                ),
                borderRadius: const BorderRadius.all(
                  Radius.circular(12.0),
                ),
                color: AppColors.cardBackgroundColor,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Center(child: Text(AppText.appName)),
              ),
            ),
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
