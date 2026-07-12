import 'package:flutter/material.dart';
import 'package:src/data/side_menu_data.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/desktop_interaction.dart';
import 'package:src/utils/global/global.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/theme_widget.dart';

class SideMenuWidget extends StatefulWidget {
  final ValueChanged<int> onPageSelected;

  const SideMenuWidget({super.key, required this.onPageSelected});

  @override
  State<SideMenuWidget> createState() => _SideMenuWidgetState();
}

class _SideMenuWidgetState extends State<SideMenuWidget> {
  Future<void> _confirmChangeConnection() async {
    final currentMode = ConnectionConfig.selectedMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.blackPearlColor,
        title: const Text(
          'Change connection?',
          style: TextStyle(color: AppColors.contentColorWhite),
        ),
        content: Text(
          currentMode == null
              ? 'You will return to connection setup. Live telemetry will stop.'
              : 'Disconnect from ${ConnectionConfig.modeTitle(currentMode)} '
                  'and choose a different connection method?',
          style: const TextStyle(color: AppColors.mainTextColor2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Routes.goToConnectionMode(context);
    }
  }

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
          CustomCard(
            color: AppColors.blackPearlColor,
            child: Column(
              children: [
                ThemeWidget(),
                InkWell(
                  mouseCursor: clickCursor,
                  onTap: _confirmChangeConnection,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.swap_horiz,
                          color: AppColors.mainTextColor2,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Change connection',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textColor,
                                ),
                              ),
                              if (ConnectionConfig.selectedMode != null)
                                Text(
                                  ConnectionConfig.modeTitle(
                                    ConnectionConfig.selectedMode!,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.mainTextColor3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (data.menu.length > displayItemsInBuildMenuEntry)
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: data.menu.length - displayItemsInBuildMenuEntry,
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
    final isSelected = Global.pageIdx == index;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(16.0),
        ),
        color: isSelected ? data.menu[index].color : Colors.transparent,
      ),
      child: InkWell(
        mouseCursor: clickCursor,
        onTap: () {
          setState(() {
            Global.pageIdx = index;
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
    final isSelected = Global.pageIdx == index;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(16.0),
        ),
        color: isSelected ? data.menu[index].color : Colors.transparent,
      ),
      child: InkWell(
        mouseCursor: clickCursor,
        onTap: () {
          setState(() {
            Global.pageIdx = index;
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
