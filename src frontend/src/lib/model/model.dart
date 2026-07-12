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
  // Pre-computed orientation from the IMU (radians). When present these are
  // preferred over recomputing from raw accelerometer data.
  double? roll;
  double? pitch;
  double? yaw;

  Model({
    this.temperature,
    this.pressure,
    this.altitude,
    this.seaPressure,
    this.acceleration,
    this.rotation,
    this.distance,
    this.gps,
    this.roll,
    this.pitch,
    this.yaw,
  });

  Model.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print(json);
    }

    // Support both nested format (old API) and flat format (WebSocket)

    // Temperature - try 'temp' first (WebSocket), then 'Temperature' (old API)
    if (json.containsKey('temp')) {
      temperature = _toDouble(json['temp']);
    } else if (json.containsKey('Temperature')) {
      temperature = _toDouble(json['Temperature']);
    }

    // Pressure - try 'press' first, then 'Pressure'
    if (json.containsKey('press')) {
      pressure = _toDouble(json['press']);
    } else if (json.containsKey('Pressure')) {
      pressure = _toDouble(json['Pressure']);
    }

    // Sea Pressure - try 'seaPress' first, then 'SeaPressure'
    if (json.containsKey('seaPress')) {
      seaPressure = _toDouble(json['seaPress']);
    } else if (json.containsKey('SeaPressure')) {
      seaPressure = _toDouble(json['SeaPressure']);
    }

    // Altitude - try 'alt' first, then 'Altitude'
    if (json.containsKey('alt')) {
      altitude = _toDouble(json['alt']);
    } else if (json.containsKey('Altitude')) {
      altitude = _toDouble(json['Altitude']);
    }

    // Acceleration - check for flat format (ax, ay, az) or nested format
    if (json.containsKey('ax') &&
        json.containsKey('ay') &&
        json.containsKey('az')) {
      acceleration = Acceleration(
        x: _toDouble(json['ax']),
        y: _toDouble(json['ay']),
        z: _toDouble(json['az']),
      );
    } else if (json.containsKey('Acceleration')) {
      acceleration = Acceleration.fromJson(json['Acceleration']);
    }

    // Rotation/Gyroscope - check for flat format (gx, gy, gz) or nested format
    if (json.containsKey('gx') &&
        json.containsKey('gy') &&
        json.containsKey('gz')) {
      rotation = Rotation(
        x: _toDouble(json['gx']),
        y: _toDouble(json['gy']),
        z: _toDouble(json['gz']),
      );
    } else if (json.containsKey('Rotation')) {
      rotation = Rotation.fromJson(json['Rotation']);
    }

    // Distance/Magnetometer - check for flat format (mx, my, mz) or nested format
    if (json.containsKey('mx') &&
        json.containsKey('my') &&
        json.containsKey('mz')) {
      distance = Distance(
        x: _toDouble(json['mx']),
        y: _toDouble(json['my']),
        z: _toDouble(json['mz']),
      );
    } else if (json.containsKey('Distance')) {
      distance = Distance.fromJson(json['Distance']);
    }

    // Pre-computed orientation (radians) — sent by the ESP32 firmware
    if (json.containsKey('roll'))  roll  = _toDouble(json['roll']);
    if (json.containsKey('pitch')) pitch = _toDouble(json['pitch']);
    if (json.containsKey('yaw'))   yaw   = _toDouble(json['yaw']);

    // GPS - check for flat format or nested format
    if (json.containsKey('lat') ||
        json.containsKey('lon') ||
        json.containsKey('head')) {
      gps = GPS(
        heading: _toDouble(json['head'] ?? 0.0),
        noOfSatellites: _toInt(json['sat'] ?? 0),
        longitude: _toDouble(json['lon'] ?? 0.0),
        latitude: _toDouble(json['lat'] ?? 0.0),
        altitude: _toDouble(json['gpsAlt'] ?? 0.0),
      );
    } else if (json.containsKey('GPS')) {
      gps = GPS.fromJson(json['GPS']);
    }
  }

  // Helper method to safely convert to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper method to safely convert to int
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
