import 'package:flutter/material.dart';
import 'package:src/charts/altitude_chart.dart';
import 'package:src/charts/pressure_chart.dart';
import 'package:src/charts/sample4.dart';
import 'package:src/charts/sample5.dart';
import 'package:src/charts/sample9.dart';
import 'package:src/charts/sample_chart.dart';
import 'package:src/charts/temperature_chart.dart';
import 'package:src/charts/temperature_graph.dart';

class InfoWidget extends StatelessWidget {
  const InfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          TemperatureGraph(),
          TemperatureChart(),
          AltitudeChart(),
          PressureChart(),
          LineChartSample6(),
          LineChartSample4(),
          LineChartSample5(),
          LineChartSample9(),
        ],
      ),
    );
  }
}
