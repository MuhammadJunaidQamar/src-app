import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';

class LineChartWidget extends StatefulWidget {
  final String type;
  const LineChartWidget({super.key, required this.type});

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  final List<FlSpot> _spots = [];
  StreamSubscription<Model>? _dataSubscription;
  int numberOfValuesShown = 10;
  String timeUnit = "seconds";
  double _xValue = 0;
  Model model = Model();
  String _currentTime = "";

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }

  void _subscribeToData() {
    final viewModel = ViewModel();

    // Subscribe to real-time WebSocket stream
    _dataSubscription = viewModel.dataStream.listen(
      (fetchedModel) {
        if (mounted) {
          setState(() {
            model = fetchedModel;
            _spots.add(FlSpot(_xValue, model.getProperty(widget.type) ?? 0));
            _xValue += 1;
            _currentTime =
                DateTime.now().toLocal().toString().split(' ')[1].split('.')[0];
            if (_spots.length > numberOfValuesShown) {
              _spots.removeAt(0);
            }
          });
        }
      },
      onError: (e) {
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
      },
    );

    // Load initial data if available
    if (viewModel.latestData != null) {
      model = viewModel.latestData!;
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
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

  Widget bottomTitleWidgets(double value, TitleMeta meta, double chartWidth) {
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.white,
      fontFamily: 'Digital',
      fontSize: 18 * chartWidth / 500,
    );
    String text;
    switch (value.toInt()) {
      case 0:
        text = _currentTime;
        break;
      case 10:
        text = '04:00';
        break;
      case 20:
        text = '08:00';
        break;
      case 20:
        text = '12:00';
        break;
      case 40:
        text = '16:00';
        break;
      case 50:
        text = '20:00';
        break;
      case 60:
        text = '23:59';
        break;
      default:
        return Container();
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(text, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
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
                    Center(
                      child: Text(
                        widget.type,
                        style: TextStyle(
                          color: Color(0xff68737d),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          minX: _spots.length > numberOfValuesShown
                              ? _xValue - numberOfValuesShown
                              : 0,
                          maxX: _spots.length > numberOfValuesShown
                              ? _xValue
                              : numberOfValuesShown.toDouble(),
                          minY: getMinY(_spots),
                          maxY: getMaxY(_spots),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: 1,
                            verticalInterval: 1,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: const Color(0xff37434d),
                              strokeWidth: 1,
                            ),
                            getDrawingVerticalLine: (value) => FlLine(
                              color: const Color(0xff37434d),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                                color: const Color(0xff37434d), width: 1),
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipRoundedRadius: 10,
                              fitInsideVertically: true,
                              fitInsideHorizontally: true,
                              maxContentWidth: 150,
                              getTooltipColor: (touchedSpot) => Colors.black,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots
                                    .map((LineBarSpot touchedSpot) {
                                  final textStyle = TextStyle(
                                    color:
                                        touchedSpot.bar.gradient?.colors[0] ??
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
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  return bottomTitleWidgets(
                                    value,
                                    meta,
                                    constraints.maxWidth,
                                  );
                                },
                                reservedSize: 30,
                              ),
                            ),
                            // bottomTitles: AxisTitles(
                            //   axisNameWidget: Text(timeUnit),
                            //   sideTitles: SideTitles(
                            //     showTitles: true,
                            //     reservedSize: 40,
                            //     interval: 10,
                            //   ),
                            // ),
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
          },
        ),
      ),
    );
  }
}
