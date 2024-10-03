import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/model/model.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/widgets/custom_card_widget.dart';

class TemperatureGraph extends StatefulWidget {
  final String type;
  const TemperatureGraph({super.key, required this.type});

  @override
  State<TemperatureGraph> createState() => _TemperatureGraphState();
}

class _TemperatureGraphState extends State<TemperatureGraph> {
  final List<FlSpot> _spots = [];
  bool _isLoading = true;
  late Timer _timer;
  final int numberOfValuesShown = 43;
  double _xValue = 0;
  Model model = Model();

  @override
  void initState() {
    super.initState();
    _startDataFetch();
  }

  void _startDataFetch() {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async => await _fetchLiveData(),
    );
  }

  Future<void> _fetchLiveData() async {
    try {
      final fetchedModel = await ViewModel.fetchWorldStates(widget.type);
      if (mounted) {
        _updateChart(fetchedModel);
      }
    } catch (e) {
      _handleError(e);
    }
  }

  void _updateChart(Model fetchedModel) {
    setState(() {
      model = fetchedModel;
      final yValue = model.getProperty(widget.type) ?? 0;
      _spots.add(FlSpot(_xValue, yValue));
      _xValue += 1;
      _isLoading = false;

      if (_spots.length > numberOfValuesShown) {
        _spots.removeAt(0);
      }
    });
  }

  void _handleError(Object error) {
    if (kDebugMode) {
      print('Error: $error');
    }
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: 'Error!',
        message: error.toString(),
        contentType: ContentType.failure,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    }
  }

  double getMinY(List<FlSpot> spots) {
    return spots.isEmpty
        ? 0
        : spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 2;
  }

  double getMaxY(List<FlSpot> spots) {
    return spots.isEmpty
        ? 10
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 2;
  }

  double getMaxX(List<FlSpot> spots) =>
      spots.isNotEmpty ? spots.last.x : numberOfValuesShown - 1.0;
  double getMinX(List<FlSpot> spots) => spots.length >= numberOfValuesShown
      ? spots.last.x - numberOfValuesShown + 1
      : 0.0;

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        children: [
          const Text('Temperature Graph',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _isLoading
              ? const CircularProgressIndicator()
              : Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: LineChart(
                      LineChartData(
                        lineTouchData:
                            LineTouchData(handleBuiltInTouches: true),
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(value.toInt().toString(),
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    value.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            color: AppColors.selectionColor,
                            barWidth: 2.5,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.selectionColor.withOpacity(0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            dotData: FlDotData(show: false),
                            spots: _spots,
                          ),
                        ],
                        minX: getMinX(_spots),
                        maxX: getMaxX(_spots),
                        minY: getMinY(_spots),
                        maxY: getMaxY(_spots),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
