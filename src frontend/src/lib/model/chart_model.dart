import 'package:flutter/material.dart';

class ChartModel {
  final String type;
  final Color lineColor;
  final String unit;
  final Widget chartWidget;

  const ChartModel({
    required this.type,
    required this.lineColor,
    required this.unit,
    required this.chartWidget,
  });
}
