import 'package:flutter/material.dart';
import 'package:src/model/chart_model.dart';

class LineChartDisplayScreen extends StatelessWidget {
  final ChartModel chartModel;

  const LineChartDisplayScreen({required this.chartModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(chartModel.type),
        titleTextStyle: TextStyle(
          color: chartModel.lineColor.withOpacity(0.2),
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Center(
        child: Hero(
          tag: chartModel.type,
          child: chartModel.chartWidget,
        ),
      ),
    );
  }
}
