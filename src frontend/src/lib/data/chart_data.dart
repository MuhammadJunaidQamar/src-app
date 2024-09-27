import 'package:src/widgets/charts/chart_widget.dart';
import 'package:src/widgets/charts/line_chart_widget.dart';
import 'package:src/widgets/charts/line_chart_widget2.dart';
import 'package:src/widgets/charts/line_chart_widget3.dart';
import 'package:src/widgets/charts/linet_widget.dart';
import 'package:src/widgets/charts/sample5.dart';
import 'package:src/widgets/charts/temperature_graph.dart';
import 'package:src/model/chart_model.dart';
import 'package:src/utils/const/constants.dart';

class ChartData {
  final charts = const <ChartModel>[
    ChartModel(
      type: 'Temperature',
      lineColor: AppColors.contentColorPink,
      unit: '°C',
      chartWidget: ChartWidget(
        type: 'Temperature',
        lineColor: AppColors.contentColorPink,
        unit: '°C',
      ),
    ),
    ChartModel(
      type: 'Pressure',
      lineColor: AppColors.contentColorCyan,
      unit: 'Pa',
      chartWidget: ChartWidget(
        type: 'Pressure',
        lineColor: AppColors.contentColorCyan,
        unit: 'Pa',
      ),
    ),
    ChartModel(
      type: 'Altitude',
      lineColor: AppColors.contentColorGreen,
      unit: 'm',
      chartWidget: ChartWidget(
        type: 'Altitude',
        lineColor: AppColors.contentColorGreen,
        unit: 'm',
      ),
    ),
    ChartModel(
      type: 'SeaPressure',
      lineColor: AppColors.contentColorBlue,
      unit: 'Pa',
      chartWidget: ChartWidget(
        type: 'SeaPressure',
        lineColor: AppColors.contentColorBlue,
        unit: 'Pa',
      ),
    ),
    ChartModel(
      type: 'SeaPressure',
      lineColor: AppColors.contentColorBlue,
      unit: 'Pa',
      chartWidget: LinetWidget(
        type: 'SeaPressure',
        lineColor: AppColors.contentColorBlue,
        unit: 'Pa',
      ),
    ),
    ChartModel(
      type: 'Temperature',
      lineColor: AppColors.contentColorPink,
      unit: '°C',
      chartWidget: LinetWidget(
        type: 'Temperature',
        lineColor: AppColors.contentColorPink,
        unit: '°C',
      ),
    ),
    ChartModel(
      type: 'Pressure',
      lineColor: AppColors.contentColorCyan,
      unit: 'Pa',
      chartWidget: LineChartWidget(type: 'Pressure'),
    ),
    ChartModel(
      type: 'Altitude',
      lineColor: AppColors.contentColorGreen,
      unit: 'm',
      chartWidget: LineChartWidget2(type: 'Altitude'),
    ),
    ChartModel(
      type: 'SeaPressure',
      lineColor: AppColors.contentColorBlue,
      unit: 'Pa',
      chartWidget: LineChart3(type: 'SeaPressure'),
    ),
    ChartModel(
      type: 'TemperatureGraph',
      lineColor: AppColors.contentColorPink,
      unit: '',
      chartWidget: TemperatureGraph(type: 'Pressure'),
    ),
    ChartModel(
      type: 'LineChartSample5',
      lineColor: AppColors.contentColorBlue,
      unit: '',
      chartWidget: LineChartSample5(
        type: 'Altitude',
      ),
    ),
  ];
}
