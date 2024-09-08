import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

import 'package:src/model/model.dart';
import 'package:src/view_model/view_model.dart';

class LiveLineChart extends StatefulWidget {
  @override
  _LiveLineChartState createState() => _LiveLineChartState();
}

class _LiveLineChartState extends State<LiveLineChart> {
  final List<FlSpot> _spots = [];
  late Timer _timer;
  final Random _random = Random();
  double _xValue = 0;
  Model model = Model();
  String type = "temperature";

  @override
  void initState() {
    super.initState();
    _startDataFeed();
  }

  void _startDataFeed() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      try {
        model = await ViewModel.fetchWorldStates(type);
        print(model);
      } catch (e) {
        if (kDebugMode) {
          print('Error: $e');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.black,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      setState(() {
        _spots.add(FlSpot(_xValue, _random.nextDouble() * 10));
        _xValue += 1;
        if (_spots.length > 50) {
          _spots.removeAt(0);
          // for (int i = 0; i < _spots.length; i++) {
          //   _spots[i] = FlSpot(i.toDouble() + 1, _spots[i].y);
          // }
          // _xValue = _spots.length.toDouble();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true),
                drawBelowEverything: true,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _spots,
                isCurved: true,
                color: model.temperature == "Esp32 not online" &&
                        model.temperature != null
                    ? Colors.red
                    : Colors.blue,
                barWidth: 4,
                isStrokeCapRound: true,
                belowBarData: BarAreaData(show: false),
              ),
            ],
            minX: _xValue > 50 ? _xValue - 50 : 0,
            maxX: _xValue > 50 ? _xValue : 50,
            minY: 0,
            maxY: 10,
          ),
        ),
      ),
    );
  }
}
