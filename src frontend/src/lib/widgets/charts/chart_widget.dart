import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';

class _LineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final Color lineColor;
  final String type;
  final String unit;
  final bool isLoading;

  const _LineChart({
    required this.spots,
    required this.type,
    required this.lineColor,
    required this.unit,
    required this.isLoading,
  });

  final int numberOfValuesShown = 9;

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator.adaptive())
        : LineChart(
            LineChartData(
              lineTouchData: LineTouchData(handleBuiltInTouches: true),
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: bottomTitles(spots)),
                leftTitles: AxisTitles(sideTitles: leftTitles(spots)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom:
                      BorderSide(color: lineColor.withOpacity(0.2), width: 4),
                  left: const BorderSide(color: Colors.transparent),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: lineColor,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                  spots: spots,
                  preventCurveOverShooting: true,
                  curveSmoothness: 0.2,
                ),
              ],
              minX: getMinX(spots),
              maxX: getMaxX(spots),
              minY: getMinY(spots),
              maxY: getMaxY(spots),
            ),
          );
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  SideTitles bottomTitles(List<FlSpot> spots) => SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: 3,
        getTitlesWidget: (double value, TitleMeta meta) {
          const style = TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          );

          double minX = getMinX(spots);
          double maxX = getMaxX(spots);

          if (value == minX || value == maxX) {
            return const Text('');
          }

          String formattedTime = _formatTime(value.toInt());
          return Text(
            formattedTime,
            style: style,
          );
        },
      );

  SideTitles leftTitles(List<FlSpot> spots) {
    final double minY = getMinY(spots);
    final double maxY = getMaxY(spots);
    final double interval = calculateYInterval(minY, maxY);
    int size = maxY.toInt().toString().length + unit.length;

    return SideTitles(
      showTitles: true,
      interval: interval,
      getTitlesWidget: (double value, TitleMeta meta) {
        const style = TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        );

        if (value == minY || value == maxY) {
          return const Text('');
        }

        return Text(
          '${value.toInt()}$unit',
          style: style,
        );
      },
      reservedSize: size * 10,
    );
  }

  double getMinY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    final minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    return minY - 2;
  }

  double getMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    return maxY + 2;
  }

  double getMaxX(List<FlSpot> spots) {
    if (spots.length > numberOfValuesShown) return spots.last.x;
    return 9.0;
  }

  double getMinX(List<FlSpot> spots) {
    if (spots.length > numberOfValuesShown) {
      return spots.last.x - numberOfValuesShown;
    }
    return 0.0;
  }

  double calculateYInterval(double minY, double maxY) {
    final range = maxY - minY;

    if (range == 0) {
      return 1.0;
    }

    final scaleFactor = range / 10;

    if (scaleFactor <= 1) {
      return 1.0;
    } else {
      final interval = (scaleFactor / 5).round() * 5;
      return interval > 0 ? interval.toDouble() : 1.0;
    }
  }
}

class ChartWidget extends StatefulWidget {
  final String type;
  final Color lineColor;
  final String unit;
  const ChartWidget(
      {super.key,
      required this.type,
      required this.lineColor,
      required this.unit});

  @override
  State<StatefulWidget> createState() => ChartWidgetState();
}

class ChartWidgetState extends State<ChartWidget> {
  late Timer _timer;
  double yValue = 0.0;
  final _spots = <FlSpot>[];
  int numberOfValuesShown = 10;
  String timeUnit = "seconds";
  double _xValue = 0;
  Model model = Model();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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

  Future<void> _fetchData() async {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async => await _fetchLiveData(),
    );
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

  void _updateChart(Model fetchedModel) {
    setState(() {
      model = fetchedModel;
      yValue = model.getProperty(widget.type) ?? 0;

      if (yValue.isFinite) {
        _spots.add(FlSpot(_xValue, yValue));
        _xValue += 1;
        _isLoading = false;

        if (_spots.length > numberOfValuesShown) {
          _spots.removeAt(0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.23,
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 37),
              Text(
                "${widget.type} ${yValue.toStringAsFixed(2)}${widget.unit}",
                style: TextStyle(
                  color: widget.lineColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 37),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, left: 6),
                  child: _LineChart(
                    spots: _spots,
                    type: widget.type,
                    lineColor: widget.lineColor,
                    unit: widget.unit,
                    isLoading: _isLoading,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );
  }
}
