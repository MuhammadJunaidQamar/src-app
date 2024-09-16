import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/widgets/custom_card_widget2.dart';

class LineChartWidget extends StatefulWidget {
  final String type;
  const LineChartWidget({super.key, required this.type});

  @override
  _LineChartWidgetState createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  final List<FlSpot> _spots = [];
  late Timer _timer;
  String timeUnit = "seconds";
  double _xValue = 0;
  Model model = Model();
  DateTime _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startDataFeed();
  }

  void _startDataFeed() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      try {
        final fetchedModel = await ViewModel.fetchWorldStates(widget.type);
        setState(() {
          model = fetchedModel;
          _spots.add(FlSpot(_xValue, model.getProperty(widget.type) ?? 0));
          _xValue += 1;
          // final elapsed = DateTime.now().difference(_startTime);
          // if (elapsed.inSeconds < 60) {
          //   _xValue = elapsed.inSeconds.toDouble();
          //   timeUnit = 'seconds';
          // } else if (elapsed.inMinutes < 60) {
          //   _xValue = elapsed.inMinutes.toDouble();
          //   timeUnit = 'minutes';
          // } else {
          //   _xValue = elapsed.inHours.toDouble();
          //   timeUnit = 'hours';
          // }
          if (_spots.length > 50) {
            _spots.removeAt(0);
          }
        });
      } catch (e) {
        if (kDebugMode) {
          print('Error: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred. Please try again later.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  double getMinY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    final minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    return minY - 5;
  }

  double getMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    return maxY + 5;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      color: const Color(0xff020227),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.type,
              style: TextStyle(
                color: Color(0xff68737d),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: _timer.tick > 50 ? _xValue - 50 : 0,
                  maxX: _timer.tick > 50 ? _xValue : 50,
                  minY: getMinY(_spots),
                  maxY: getMaxY(_spots),
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: const Color(0xff37434d),
                      strokeWidth: 1,
                    ),
                    drawVerticalLine: true,
                    getDrawingVerticalLine: (value) => FlLine(
                      color: const Color(0xff37434d),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border:
                        Border.all(color: const Color(0xff37434d), width: 1),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 10,
                      fitInsideVertically: true,
                      fitInsideHorizontally: true,
                      maxContentWidth: 150,
                      getTooltipColor: (touchedSpot) => Colors.black,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final textStyle = TextStyle(
                            color: touchedSpot.bar.gradient?.colors[0] ??
                                touchedSpot.bar.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          );
                          return LineTooltipItem(
                            '$timeUnit:${touchedSpot.x}, ${widget.type}:${touchedSpot.y.toStringAsFixed(2)}',
                            textStyle,
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                    getTouchLineStart: (data, index) => 0,
                  ),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(timeUnit),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 10,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(widget.type),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _spots,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xff23b6e6),
                          const Color(0xff02d39a),
                        ],
                      ),
                      barWidth: 5,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xff23b6e6).withOpacity(0.3),
                            const Color(0xff02d39a).withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
