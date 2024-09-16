import 'package:flutter/material.dart';
import 'package:src/charts/altitude_chart.dart';
import 'package:src/charts/line_chart_widget.dart';
import 'package:src/charts/pressure_chart.dart';
import 'package:src/charts/sample4.dart';
import 'package:src/charts/sample5.dart';
import 'package:src/charts/sample_chart.dart';
import 'package:src/charts/temperature_chart.dart';
import 'package:src/charts/temperature_graph.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/widgets/custom_card_widget2.dart';

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
        shrinkWrap: true, // Makes GridView take only as much space as needed
        physics:
            NeverScrollableScrollPhysics(), // Prevents nested scrolling issues

        children: <Widget>[
          LineChartWidget(
            type: 'temperature',
          ),
          TemperatureGraph(),
          TemperatureChart(),
          AltitudeChart(),
          PressureChart(),
          LineChartSample6(),
          LineChartSample4(),
          LineChartSample5(),
          // Add more widgets if needed
        ],
      ),
    );
  }
}
