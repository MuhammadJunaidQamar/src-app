import 'dart:ffi';

import 'package:flutter/foundation.dart';

class Model {
  double? temperature;
  // String? altitude;
  String? left;
  String? right;
  String? up;
  String? down;

  Model({
    this.temperature,
    // this.altitude,
    this.left,
    this.right,
    this.up,
    this.down,
  });

  Model.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print(json);
    }
    if (json['Temperature'] is int) {
      temperature = json['Temperature'].toDouble();
    } else if (json['Temperature'] is double) {
      temperature = json['Temperature'];
    } else {
      throw ArgumentError('Unsupported data type');
    }
    // altitude = json['Altitude'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['Left'] = left;
    data['Right'] = right;
    data['Up'] = up;
    data['Down'] = down;
    return data;
  }

  dynamic getProperty(String key) {
    switch (key) {
      case 'temperature':
        return temperature;
      default:
        return 'Unknown property';
    }
  }
}
