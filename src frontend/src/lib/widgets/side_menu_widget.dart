import 'package:flutter/material.dart';
import 'package:src/data/side_menu_data.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/connection/connection_config.dart';
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
    final colors = context.colors;
    final currentMode = ConnectionConfig.selectedMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        title: Text(
          'Change connection?',
          style: TextStyle(color: colors.textStrong),
        ),
        content: Text(
          currentMode == null
              ? 'You will return to connection setup. Live telemetry will stop.'
              : 'Disconnect from ${ConnectionConfig.modeTitle(currentMode)} '
                  'and choose a different connection method?',
          style: TextStyle(color: colors.textSecondary),
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
    final colors = context.colors;
    final data = SideMenuData();
    final int displayItemsInBuildMenuEntry = 3;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Column(
        children: [
          CustomCard(
            color: colors.surfaceElevated,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: data.menu.length > displayItemsInBuildMenuEntry
                  ? displayItemsInBuildMenuEntry
                  : data.menu.length,
              itemBuilder: (context, index) =>
                  buildMenuEntry(data, index, colors),
            ),
          ),
          Spacer(),
          CustomCard(
            color: colors.surfaceElevated,
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
                        Icon(
                          Icons.swap_horiz,
                          color: colors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change connection',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (ConnectionConfig.selectedMode != null)
                                Text(
                                  ConnectionConfig.modeTitle(
                                    ConnectionConfig.selectedMode!,
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textTertiary,
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
                        data, index + displayItemsInBuildMenuEntry, colors),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget buildMenuEntry(SideMenuData data, int index, AppThemeColors colors) {
    return _menuRow(data, index, colors);
  }

  Widget infoAndThemeCorner(
      SideMenuData data, int index, AppThemeColors colors) {
    return _menuRow(data, index, colors);
  }

  Widget _menuRow(SideMenuData data, int index, AppThemeColors colors) {
    final isSelected = Global.pageIdx == index;
    final entryColor = colors.tuneAccent(data.menu[index].color);
    // Yellows/oranges stay too light to carry white, so deepen the selected
    // fill instead of flipping Dashboard's label to black.
    final selectedFill = _selectedMenuFill(entryColor);
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(16.0),
        ),
        color: isSelected ? selectedFill : Colors.transparent,
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
                color: isSelected ? colors.onAccent : entryColor,
              ),
            ),
            Text(
              data.menu[index].title,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? colors.onAccent : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Darken [fill] until white ([AppThemeColors.onAccent]) has at least 3:1
/// contrast. Indigo/blue/green rows already pass; Dashboard's koromiko orange
/// does not, which is why its selected label used to stay black in light mode.
Color _selectedMenuFill(Color fill) {
  var hsl = HSLColor.fromColor(fill);
  while (1.05 / (fill.computeLuminance() + 0.05) < 3.0 &&
      hsl.lightness > 0.18) {
    hsl = hsl.withLightness((hsl.lightness - 0.05).clamp(0.0, 1.0));
    fill = hsl.toColor();
  }
  return fill;
}
