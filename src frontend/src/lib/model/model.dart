import 'package:flutter/foundation.dart';

class Acceleration {
  double x;
  double y;
  double z;

  Acceleration({required this.x, required this.y, required this.z});

  Acceleration.fromJson(Map<String, dynamic> json)
      : x = (json['X'] is int) ? json['X'].toDouble() : json['X'],
        y = (json['Y'] is int) ? json['Y'].toDouble() : json['Y'],
        z = (json['Z'] is int) ? json['Z'].toDouble() : json['Z'];

  Map<String, dynamic> toJson() {
    return {
      'X': x,
      'Y': y,
      'Z': z,
    };
  }
}

class Rotation {
  double x;
  double y;
  double z;

  Rotation({required this.x, required this.y, required this.z});

  Rotation.fromJson(Map<String, dynamic> json)
      : x = (json['X'] is int) ? json['X'].toDouble() : json['X'],
        y = (json['Y'] is int) ? json['Y'].toDouble() : json['Y'],
        z = (json['Z'] is int) ? json['Z'].toDouble() : json['Z'];

  Map<String, dynamic> toJson() {
    return {
      'X': x,
      'Y': y,
      'Z': z,
    };
  }
}

class Distance {
  double x;
  double y;
  double z;

  Distance({required this.x, required this.y, required this.z});

  Distance.fromJson(Map<String, dynamic> json)
      : x = (json['X'] is int) ? json['X'].toDouble() : json['X'],
        y = (json['Y'] is int) ? json['Y'].toDouble() : json['Y'],
        z = (json['Z'] is int) ? json['Z'].toDouble() : json['Z'];

  Map<String, dynamic> toJson() {
    return {
      'X': x,
      'Y': y,
      'Z': z,
    };
  }
}

class GPS {
  double heading;
  int noOfSatellites;
  double longitude;
  double latitude;
  double altitude;

  GPS(
      {required this.heading,
      required this.noOfSatellites,
      required this.longitude,
      required this.latitude,
      required this.altitude});

  GPS.fromJson(Map<String, dynamic> json)
      : heading = (json['heading'] is int)
            ? json['heading'].toDouble()
            : json['heading'],
        noOfSatellites = json['noOfSatellites'],
        longitude = (json['longitude'] is int)
            ? json['longitude'].toDouble()
            : json['longitude'],
        latitude = (json['latitude'] is int)
            ? json['latitude'].toDouble()
            : json['latitude'],
        altitude = (json['altitude'] is int)
            ? json['altitude'].toDouble()
            : json['altitude'];

  Map<String, dynamic> toJson() {
    return {
      'Heading': heading,
      'NoOfSatellites': noOfSatellites,
      'Longitude': longitude,
      'Latitude': latitude,
      'Altitude': altitude,
    };
  }
}

class Model {
  double? temperature;
  double? pressure;
  double? altitude;
  double? seaPressure;
  Acceleration? acceleration;
  Rotation? rotation;
  Distance? distance;
  GPS? gps;

  Model({
    this.temperature,
    this.pressure,
    this.altitude,
    this.seaPressure,
    this.acceleration,
    this.rotation,
    this.distance,
    this.gps,
  });

  Model.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print(json);
    }

    temperature = (json['Temperature'] is int)
        ? json['Temperature'].toDouble()
        : json['Temperature'];
    pressure = (json['Pressure'] is int)
        ? json['Pressure'].toDouble()
        : json['Pressure'];
    altitude = (json['Altitude'] is int)
        ? json['Altitude'].toDouble()
        : json['Altitude'];
    seaPressure = (json['SeaPressure'] is int)
        ? json['SeaPressure'].toDouble()
        : json['SeaPressure'];

    if (json.containsKey('Acceleration')) {
      acceleration = Acceleration.fromJson(json['Acceleration']);
    }
    if (json.containsKey('Rotation')) {
      rotation = Rotation.fromJson(json['Rotation']);
    }
    if (json.containsKey('Distance')) {
      distance = Distance.fromJson(json['Distance']);
    }
    if (json.containsKey('GPS')) {
      gps = GPS.fromJson(json['GPS']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['Temperature'] = temperature;
    data['Pressure'] = pressure;
    data['Altitude'] = altitude;
    data['SeaPressure'] = seaPressure;

    if (acceleration != null) {
      data['Acceleration'] = acceleration!.toJson();
    }
    if (rotation != null) {
      data['Rotation'] = rotation!.toJson();
    }
    if (distance != null) {
      data['Distance'] = distance!.toJson();
    }
    if (gps != null) {
      data['GPS'] = gps!.toJson();
    }

    return data;
  }

  dynamic getProperty(String key) {
    switch (key) {
      case 'Temperature':
        return temperature;
      case 'Pressure':
        return pressure;
      case 'Altitude':
        return altitude;
      case 'SeaPressure':
        return seaPressure;
      case 'Acceleration':
        return acceleration;
      case 'Rotation':
        return rotation;
      case 'Distance':
        return distance;
      case 'GPS':
        return gps;
      default:
        return 'Unknown property';
    }
  }
}
