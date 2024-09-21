import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/model/model.dart';
import 'package:src/utils/const/constants.dart';
import 'package:src/view_model/view_model.dart';

class _LineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final String type;

  const _LineChart({required this.spots, required this.type});

  final int numberOfValuesShown = 9;

  @override
  Widget build(BuildContext context) {
    return LineChart(
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
                BorderSide(color: AppColors.primary.withOpacity(0.2), width: 4),
            left: const BorderSide(color: Colors.transparent),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: AppColors.contentColorGreen,
            barWidth: 8,
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

  SideTitles bottomTitles(List<FlSpot> spots) => SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: 5,
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

          return Text(
            value.toInt().toString(),
            style: style,
          );
        },
      );

  SideTitles leftTitles(List<FlSpot> spots) => SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: calculateYInterval(getMinY(spots), getMaxY(spots)),
        getTitlesWidget: (double value, TitleMeta meta) {
          const style = TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          );

          double minY = getMinY(spots);
          double maxY = getMaxY(spots);

          if (value == minY || value == maxY) {
            return const Text('');
          }

          return Text(
            '$value°C',
            style: style,
          );
        },
      );

  double getMinY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    final minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    return minY - 1;
  }

  double getMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    return maxY + 1;
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
    if (range < 5) {
      return 1;
    } else if (range < 20) {
      return 2;
    } else {
      return 5;
    }
  }
}

class AltitudeChart extends StatefulWidget {
  final String type;
  const AltitudeChart({super.key, required this.type});

  @override
  State<StatefulWidget> createState() => AltitudeChartState();
}

class AltitudeChartState extends State<AltitudeChart> {
  late Timer _timer;
  List<FlSpot> _spots = [];
  int numberOfValuesShown = 10;
  String timeUnit = "seconds";
  double _xValue = 0;
  Model model = Model();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(microseconds: 500),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _fetchData() async {
    try {
      final response = await ViewModel.fetchWorldStates(widget.type);
      setState(() {
        model = response;
        _spots.add(FlSpot(_xValue, model.getProperty(widget.type) ?? 0));
        _xValue += 1;

        if (_spots.length > numberOfValuesShown) {
          _spots.removeAt(0);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
      _showSnackBar(e.toString());
    }
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
                widget.type,
                style: TextStyle(
                  color: AppColors.primary,
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
