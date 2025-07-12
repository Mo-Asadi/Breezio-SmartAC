import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SensorDataProvider extends ChangeNotifier {
  final String deviceId;
  final DatabaseReference _sensorRef;

  double roomTemp = 0.0;
  double roomHumidity = 0.0;
  bool motion = false;
  int eco2 = 250;
  int tvoc = 100;
  int aqi = 60;

  SensorDataProvider(this.deviceId)
      : _sensorRef = FirebaseDatabase.instance.ref('devices/$deviceId/sensors') {
    _initListener();
  }

  void _initListener() {
    _sensorRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      roomTemp = (data['roomTemperature'] ?? roomTemp).toDouble();
      roomHumidity = (data['roomHumidity'] ?? roomHumidity).toDouble();
      motion = data['motion'] ?? motion;
      eco2 = data['eco2'] ?? eco2;
      tvoc = data['tvoc'] ?? tvoc;
      aqi = data['aqi'] ?? aqi;

      notifyListeners();
    });
  }
}