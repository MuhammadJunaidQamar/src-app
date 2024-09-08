import 'package:flutter/foundation.dart';

class Model {
  String? temperature;
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
    temperature = json['temperature'];
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
}
