import 'package:flutter/material.dart';
import 'package:src/data/side_menu_data.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/theme_widget.dart';

class SideMenuWidget extends StatefulWidget {
  final ValueChanged<int> onPageSelected;

  const SideMenuWidget({super.key, required this.onPageSelected});

  @override
  State<SideMenuWidget> createState() => _SideMenuWidgetState();
}

class _SideMenuWidgetState extends State<SideMenuWidget> {
  @override
  Widget build(BuildContext context) {
    final data = SideMenuData();
    final int displayItemsInBuildMenuEntry = 3;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Column(
        children: [
          CustomCard(
            color: AppColors.blackPearlColor,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: data.menu.length > displayItemsInBuildMenuEntry
                  ? displayItemsInBuildMenuEntry
                  : data.menu.length,
              itemBuilder: (context, index) => buildMenuEntry(data, index),
            ),
          ),
          Spacer(),
          if (data.menu.length > displayItemsInBuildMenuEntry)
            CustomCard(
              color: AppColors.blackPearlColor,
              child: Column(
                children: [
                  ThemeWidget(),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: data.menu.length > displayItemsInBuildMenuEntry
                        ? data.menu.length - displayItemsInBuildMenuEntry
                        : 0,
                    itemBuilder: (context, index) => infoAndThemeCorner(
                        data, index + displayItemsInBuildMenuEntry),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget buildMenuEntry(SideMenuData data, int index) {
    final isSelected = Constants.pageIdx == index;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(16.0),
        ),
        color: isSelected ? data.menu[index].color : Colors.transparent,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            Constants.pageIdx = index;
          });
          widget.onPageSelected(index);
        },
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              child: Icon(
                data.menu[index].icon,
                color: isSelected
                    ? AppColors.backgroundColor
                    : data.menu[index].color,
              ),
            ),
            Text(
              data.menu[index].title,
              style: TextStyle(
                fontSize: 16,
                color: isSelected
                    ? AppColors.backgroundColor
                    : AppColors.textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoAndThemeCorner(SideMenuData data, int index) {
    final isSelected = Constants.pageIdx == index;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(16.0),
        ),
        color: isSelected ? data.menu[index].color : Colors.transparent,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            Constants.pageIdx = index;
          });
          widget.onPageSelected(index);
        },
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              child: Icon(
                data.menu[index].icon,
                color: isSelected
                    ? AppColors.backgroundColor
                    : data.menu[index].color,
              ),
            ),
            Text(
              data.menu[index].title,
              style: TextStyle(
                fontSize: 16,
                color: isSelected
                    ? AppColors.backgroundColor
                    : AppColors.textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
