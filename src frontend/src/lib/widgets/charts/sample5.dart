import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:src/model/model.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/view_model/view_model.dart';

class LineChartSample5 extends StatefulWidget {
  final String type;
  const LineChartSample5({
    super.key,
    Color? gradientColor1,
    Color? gradientColor2,
    Color? gradientColor3,
    Color? indicatorStrokeColor,
    required this.type,
  })  : gradientColor1 = gradientColor1 ?? AppColors.selectionColor,
        gradientColor2 = gradientColor2 ?? AppColors.selectionColor,
        gradientColor3 = gradientColor3 ?? AppColors.selectionColor,
        indicatorStrokeColor = indicatorStrokeColor ?? AppColors.selectionColor;

  final Color gradientColor1;
  final Color gradientColor2;
  final Color gradientColor3;
  final Color indicatorStrokeColor;

  @override
  State<LineChartSample5> createState() => _LineChartSample5State();
}

class _LineChartSample5State extends State<LineChartSample5> {
  List<int> showingTooltipOnSpots = [1, 3, 5];
  final List<FlSpot> _spots = [];
  bool _isLoading = true;
  late Timer _timer;
  final int numberOfValuesShown = 10;
  double _xValue = 0;
  Model model = Model();

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
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

  Widget bottomTitleWidgets(double value, TitleMeta meta, double chartWidth) {
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      color: AppColors.contentColorPink,
      fontFamily: 'Digital',
      fontSize: 18 * chartWidth / 500,
    );
    String text;
    switch (value.toInt()) {
      case 0:
        text = '00:00';
        break;
      case 1:
        text = '04:00';
        break;
      case 2:
        text = '08:00';
        break;
      case 3:
        text = '12:00';
        break;
      case 4:
        text = '16:00';
        break;
      case 5:
        text = '20:00';
        break;
      case 6:
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
    final lineBarsData = [
      LineChartBarData(
        showingIndicators: showingTooltipOnSpots,
        spots: _spots,
        isCurved: true,
        barWidth: 4,
        shadow: const Shadow(blurRadius: 8),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              widget.gradientColor1.withOpacity(0.4),
              widget.gradientColor2.withOpacity(0.4),
              widget.gradientColor3.withOpacity(0.4),
            ],
          ),
        ),
        dotData: const FlDotData(show: false),
        gradient: LinearGradient(
          colors: [
            widget.gradientColor1,
            widget.gradientColor2,
            widget.gradientColor3,
          ],
          stops: const [0.1, 0.4, 0.9],
        ),
      ),
    ];

    final tooltipsOnBar = lineBarsData[0];

    return AspectRatio(
      aspectRatio: 2.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(builder: (context, constraints) {
                return LineChart(
                  LineChartData(
                    showingTooltipIndicators:
                        showingTooltipOnSpots.map((index) {
                      if (index < tooltipsOnBar.spots.length) {
                        return ShowingTooltipIndicators([
                          LineBarSpot(
                            tooltipsOnBar,
                            lineBarsData.indexOf(tooltipsOnBar),
                            tooltipsOnBar.spots[index],
                          ),
                        ]);
                      } else {
                        return ShowingTooltipIndicators([]);
                      }
                    }).toList(),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: false,
                      touchCallback:
                          (FlTouchEvent event, LineTouchResponse? response) {
                        if (response == null || response.lineBarSpots == null) {
                          return;
                        }

                        if (response.lineBarSpots!.isNotEmpty) {
                          if (event is FlTapUpEvent) {
                            final spotIndex =
                                response.lineBarSpots!.first.spotIndex;
                            setState(() {
                              if (showingTooltipOnSpots.contains(spotIndex)) {
                                showingTooltipOnSpots.remove(spotIndex);
                              } else {
                                showingTooltipOnSpots.add(spotIndex);
                              }
                            });
                          }
                        }
                      },
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border:
                          Border.all(color: AppColors.mainTextColor1, width: 1),
                    ),
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: true)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => bottomTitleWidgets(
                              value, meta, constraints.maxWidth),
                        ),
                      ),
                    ),
                    lineBarsData: lineBarsData,
                  ),
                );
              }),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
