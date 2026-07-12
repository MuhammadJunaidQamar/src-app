import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';

class _LineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<int> spotTimes;
  final Color lineColor;
  final String type;
  final String unit;
  final bool isLoading;
  final int numberOfValuesShown;

  const _LineChart({
    required this.spots,
    required this.spotTimes,
    required this.type,
    required this.lineColor,
    required this.unit,
    required this.isLoading,
    required this.numberOfValuesShown,
  });

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator.adaptive())
        : ClipRect(
            child: LineChart(
            LineChartData(
              clipData: const FlClipData.all(),
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
        interval: (numberOfValuesShown / 3).ceilToDouble(),
        getTitlesWidget: (double value, TitleMeta meta) {
          const style = TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          );

          final int index = value.round();
          if (index <= 0 || index >= spots.length - 1) {
            return const Text('');
          }

          if (index >= spotTimes.length) {
            return const Text('');
          }

          return Text(
            _formatTime(spotTimes[index]),
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

  double getMaxX(List<FlSpot> spots) => (numberOfValuesShown - 1).toDouble();

  double getMinX(List<FlSpot> spots) => 0;

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
  final String? title;
  final Color lineColor;
  final String unit;
  const ChartWidget({
    super.key,
    required this.type,
    this.title,
    required this.lineColor,
    required this.unit,
  });

  String get displayTitle => title ?? type;

  @override
  State<StatefulWidget> createState() => ChartWidgetState();
}

class ChartWidgetState extends State<ChartWidget> {
  StreamSubscription<Model>? _dataSubscription;
  double yValue = 0.0;
  final _spots = <FlSpot>[];
  final _spotTimes = <int>[];
  // More points = slower horizontal scroll and line stays inside the chart.
  int numberOfValuesShown = 100;
  String timeUnit = "seconds";
  double _xValue = 0;
  Model model = Model();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToData() {
    final viewModel = ViewModel();

    // Subscribe to real-time WebSocket stream
    _dataSubscription = viewModel.dataStream.listen(
      (fetchedModel) {
        if (mounted) {
          _updateChart(fetchedModel);
        }
      },
      onError: (error) {
        _handleError(error);
      },
    );

    // Load initial data if available
    if (viewModel.latestData != null) {
      _updateChart(viewModel.latestData!);
    }
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
        _spots.add(FlSpot(_spots.length.toDouble(), yValue));
        _spotTimes.add(_xValue.toInt());
        _xValue += 1;
        _isLoading = false;

        if (_spots.length > numberOfValuesShown) {
          _spots.removeAt(0);
          _spotTimes.removeAt(0);
          for (var i = 0; i < _spots.length; i++) {
            _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
          }
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
                "${widget.displayTitle} ${yValue.toStringAsFixed(2)}${widget.unit}",
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
                    spotTimes: _spotTimes,
                    type: widget.type,
                    lineColor: widget.lineColor,
                    unit: widget.unit,
                    isLoading: _isLoading,
                    numberOfValuesShown: numberOfValuesShown,
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
