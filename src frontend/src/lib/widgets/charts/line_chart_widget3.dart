import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
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

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(handleBuiltInTouches: true),
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: bottomTitles),
          leftTitles: AxisTitles(sideTitles: leftTitles()),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 4,
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: AppColors.contentColorGreen,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            spots: spots,
          ),
        ],
        minX: spots.isNotEmpty ? spots.last.x - 9.0 : 0,
        maxX: spots.isNotEmpty ? spots.last.x : 9.0,
        minY: getMinY(spots),
        maxY: getMaxY(spots),
      ),
    );
  }

  static SideTitles get bottomTitles => SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: 1,
        getTitlesWidget: (double value, TitleMeta meta) {
          const style = TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          );
          switch (value.toInt()) {
            case 2:
              return const Text('SEPT', style: style);
            case 7:
              return const Text('OCT', style: style);
            case 12:
              return const Text('DEC', style: style);
            default:
              return const Text('');
          }
        },
      );

  static SideTitles leftTitles() => SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (double value, TitleMeta meta) {
          const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);
          switch (value.toInt()) {
            case 1:
              return const Text('1m', style: style);
            case 2:
              return const Text('2m', style: style);
            case 3:
              return const Text('3m', style: style);
            case 4:
              return const Text('5m', style: style);
            default:
              return const Text('');
          }
        },
        interval: 1,
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
}

class LineChart3 extends StatefulWidget {
  final String type;
  const LineChart3({super.key, required this.type});

  @override
  State<StatefulWidget> createState() => LineChart3State();
}

class LineChart3State extends State<LineChart3> {
  late Timer _timer;
  final List<FlSpot> _spots = [];
  int numberOfValuesShown = 10;
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
      SnackBar snackBar = SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(
          title: 'On Snap!',
          message: e.toString(),
          contentType: ContentType.failure,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(snackBar);
      }
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
