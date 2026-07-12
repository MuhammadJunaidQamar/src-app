import 'package:flutter/material.dart';
import 'package:src/data/chart_data.dart';
import 'package:src/utils/desktop_interaction.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/model/chart_model.dart';
import 'package:src/utils/routing/routes_name.dart';

class InfoWidget extends StatelessWidget {
  const InfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ChartModel> chartData = ChartData().charts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.isTablet(context) ? 2 : 1,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: chartData.length,
        itemBuilder: (context, index) {
          return withClickCursor(
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  RouteName.lineChartDisplayScreen,
                  arguments: chartData[index],
                );
              },
              child: Hero(
                tag: chartData[index].type,
                child: chartData[index].chartWidget,
              ),
            ),
          );
        },
      ),
    );
  }
}
