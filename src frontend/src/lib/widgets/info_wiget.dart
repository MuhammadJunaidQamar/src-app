import 'package:flutter/material.dart';
import 'package:src/charts/chart_widget.dart';
import 'package:src/charts/line_chart_widget.dart';
import 'package:src/charts/line_chart_widget2.dart';
import 'package:src/charts/line_chart_widget3.dart';
import 'package:src/charts/pressure_chart.dart';
import 'package:src/charts/sample5.dart';
import 'package:src/charts/temperature_graph.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/utils/responsive.dart';

class InfoWidget extends StatelessWidget {
  const InfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: GridView.count(
        crossAxisCount: Responsive.isTablet(context) ? 2 : 1,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        children: <Widget>[
          ChartWidget(
            type: 'Temperature',
            lineColour: AppColors.contentColorPink,
            unit: '°C',
          ),
          ChartWidget(
            type: 'Pressure',
            lineColour: AppColors.contentColorCyan,
            unit: ' Pa',
          ),
          ChartWidget(
            type: 'Altitude',
            lineColour: AppColors.contentColorGreen,
            unit: 'm',
          ),
          ChartWidget(
            type: 'SeaPressure',
            lineColour: AppColors.contentColorBlue,
            unit: 'Pa',
          ),
          LineChartWidget(
            type: 'Pressure',
          ),
          LineChartWidget2(
            type: 'Altitude',
          ),
          LineChart3(
            type: 'SeaPressure',
          ),
          TemperatureGraph(),
          PressureChart(),
          LineChartSample5(),
        ],
      ),
    );
  }
}
