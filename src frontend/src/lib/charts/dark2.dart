import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Live Line Chart')),
        body: DarkThemeLineChart(),
      ),
    );
  }
}

class DarkThemeLineChart extends StatefulWidget {
  @override
  _DarkThemeLineChartState createState() => _DarkThemeLineChartState();
}

class _DarkThemeLineChartState extends State<DarkThemeLineChart> {
  List<FlSpot> spots = [];
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final newSpot = FlSpot(now.millisecondsSinceEpoch.toDouble(),
          (now.second + now.millisecond / 1000).toDouble());

      setState(() {
        spots.add(newSpot);
        if (spots.length > 20) {
          spots.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Dark theme background
      padding: EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: const Color(0xff37434d),
              width: 1,
            ),
          ),
          minX: DateTime.now()
              .subtract(Duration(minutes: 1))
              .millisecondsSinceEpoch
              .toDouble(),
          maxX: DateTime.now().millisecondsSinceEpoch.toDouble(),
          minY: 0,
          maxY: 60,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue, // Correct parameter for line color
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
