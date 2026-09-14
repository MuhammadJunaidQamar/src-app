import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/model/model.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/view_model/view_model.dart';

class _LineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final String type;

  const _LineChart({required this.spots, required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Captured here so the fl_chart closures below never need a BuildContext.
    final axisLabelColor = colors.textSecondary;
    final gridLineColor = colors.gridLine;

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => colors.surfaceElevated,
            tooltipBorder: BorderSide(color: colors.cardBorder),
          ),
        ),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (value) => FlLine(
            color: gridLineColor,
            strokeWidth: 0.4,
            dashArray: const [8, 4],
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: gridLineColor,
            strokeWidth: 0.4,
            dashArray: const [8, 4],
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: bottomTitles(axisLabelColor)),
          leftTitles: AxisTitles(sideTitles: leftTitles(axisLabelColor)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: colors.cardBorder,
            width: 4,
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: colors.tuneAccent(AppColors.contentColorGreen),
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

  static SideTitles bottomTitles(Color labelColor) => SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: 1,
        getTitlesWidget: (double value, TitleMeta meta) {
          final style = TextStyle(
            color: labelColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          );
          switch (value.toInt()) {
            case 2:
              return Text('SEPT', style: style);
            case 7:
              return Text('OCT', style: style);
            case 12:
              return Text('DEC', style: style);
            default:
              return const Text('');
          }
        },
      );

  static SideTitles leftTitles(Color labelColor) => SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (double value, TitleMeta meta) {
          final style = TextStyle(
            color: labelColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          );
          switch (value.toInt()) {
            case 1:
              return Text('1m', style: style);
            case 2:
              return Text('2m', style: style);
            case 3:
              return Text('3m', style: style);
            case 4:
              return Text('5m', style: style);
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
  StreamSubscription<Model>? _dataSubscription;
  final List<FlSpot> _spots = [];
  int numberOfValuesShown = 10;
  double _xValue = 0;
  Model model = Model();

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
          setState(() {
            model = fetchedModel;
            _spots.add(FlSpot(_xValue, model.getProperty(widget.type) ?? 0));
            _xValue += 1;

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
                  color: context.colors.info,
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
