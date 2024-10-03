import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/model/model.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/view_model/view_model.dart';

class LineWidget extends StatefulWidget {
  final String type;
  final Color lineColor;
  final String unit;
  const LineWidget(
      {super.key,
      required this.type,
      required this.lineColor,
      required this.unit});

  @override
  State<LineWidget> createState() => _LineWidgetState();
}

class _LineWidgetState extends State<LineWidget> {
  final limitCount = 10;
  final _spots = <FlSpot>[];

  double xValue = 0;

  late Timer timer;

  Model model = Model();

  @override
  void initState() {
    super.initState();
    _fetchData();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    try {
      final response = await ViewModel.fetchWorldStates(widget.type);
      setState(() {
        model = response;

        _spots.add(FlSpot(xValue, model.getProperty(widget.type) ?? 0));
        xValue += 1;

        if (_spots.length > limitCount) {
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

  double getMinY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    return spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) - 2;
  }

  double getMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    return spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 2;
  }

  double getMaxX(List<FlSpot> spots) {
    return spots.isNotEmpty ? spots.last.x : 9.0;
  }

  double getMinX(List<FlSpot> spots) {
    return spots.isNotEmpty ? spots.last.x - limitCount : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    var currentTime =
        DateTime.now().toLocal().toString().split(' ')[1].split('.')[0];
    return _spots.isNotEmpty
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Text(
                'time: $currentTime',
                style: const TextStyle(
                  color: AppColors.mainTextColor2,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${widget.type}: ${_spots.last.y.toStringAsFixed(1)}${widget.unit}',
                style: TextStyle(
                  color: widget.lineColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1.5,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: LineChart(
                    LineChartData(
                      minX: getMinX(_spots),
                      maxX: getMaxX(_spots),
                      minY: getMinY(_spots),
                      maxY: getMaxY(_spots),
                      lineTouchData: const LineTouchData(enabled: false),
                      clipData: const FlClipData.all(),
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        singleLine(_spots),
                      ],
                      titlesData: const FlTitlesData(
                        show: false,
                      ),
                    ),
                  ),
                ),
              )
            ],
          )
        : Container();
  }

  LineChartBarData singleLine(List<FlSpot> points) {
    return LineChartBarData(
      spots: points,
      dotData: const FlDotData(
        show: false,
      ),
      gradient: LinearGradient(
        colors: [widget.lineColor.withOpacity(0), widget.lineColor],
        stops: const [0.1, 1.0],
      ),
      barWidth: 4,
      isCurved: false,
    );
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }
}
