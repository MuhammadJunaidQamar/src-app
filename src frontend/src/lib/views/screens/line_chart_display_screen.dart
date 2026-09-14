import 'package:flutter/material.dart';
import 'package:src/model/chart_model.dart';
import 'package:src/theme/app_theme_colors.dart';

class LineChartDisplayScreen extends StatelessWidget {
  final ChartModel chartModel;

  const LineChartDisplayScreen({required this.chartModel, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(chartModel.type),
        titleTextStyle: TextStyle(
          // Series colour, darkened on light canvases so the title stays legible.
          color: context.colors.tuneAccent(chartModel.lineColor),
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
        forceMaterialTransparency: true,
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
