import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ACMaintenanceProvider extends ChangeNotifier {
  final String deviceId;
  final DatabaseReference _statusRef;

  double totalHours = 0.0;
  double capacityHours = 250.0;
  bool buzz = true;


  ACMaintenanceProvider(this.deviceId)
      : _statusRef = FirebaseDatabase.instance.ref('devices/$deviceId/maintenance') {
    _initListener();
  }

  void _initListener() {
    _statusRef.onValue.listen((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return;

      final data = Map<String, dynamic>.from(raw);
    
      totalHours = (data['totalHours'] as num?)?.toDouble() ?? totalHours;
      capacityHours = (data['capacityHours'] as num?)?.toDouble() ?? capacityHours;
      buzz = data['buzz'] == true;

      notifyListeners();
    });
  }

  Future<void> setBuzz(bool value) async {
    await _statusRef.update({'buzz': value});
  }

  Future<void> setTotalHours(double hours) async {
    await _statusRef.update({'totalHours': hours});
  }
}