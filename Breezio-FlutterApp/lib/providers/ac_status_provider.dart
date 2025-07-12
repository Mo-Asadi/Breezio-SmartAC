import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ACStatusProvider extends ChangeNotifier {
  final String deviceId;
  final DatabaseReference _statusRef;

  bool powered = false;
  int currentTimer = 30;
  double currentTemp = 24.0;
  String mode = 'regular';
  bool lightsOn = false;
  bool relayOn = false;
  String idleFlag = 'active';
  String name = 'BreezioAC';

  ACStatusProvider(this.deviceId)
      : _statusRef = FirebaseDatabase.instance.ref('devices/$deviceId/status') {
    _initListener();
  }

  void _initListener() {
    _statusRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      powered = data['powered'] ?? powered;
      currentTimer = data['currentTimer'] ?? currentTimer;
      currentTemp = (data['currentTemperature'] ?? currentTemp).toDouble();
      mode = data['mode'] ?? mode;
      lightsOn = data['lightsOn'] ?? lightsOn;
      relayOn = data['relayOn'] ?? relayOn;
      idleFlag = data['idleFlag'] ?? idleFlag;
      name = data['name'] ?? name;

      notifyListeners();
    });
  }

  Future<void> setPower(bool value) async {
    powered = value;
    await _statusRef.update({'powered': value});
    notifyListeners();
  }

  Future<void> setName(String newName) async {
    name = newName;
    await _statusRef.update({'name': newName});
    notifyListeners();
  }

  Future<bool> setTemperature(double temp) async {
    final configRef = FirebaseDatabase.instance.ref("devices/$deviceId/config");
    final snapshot = await configRef.get();
    final config = snapshot.value as Map?;

    if (config == null) return false;

    final minTemp = (config['minTemperature'] ?? 16).toDouble();
    final maxTemp = (config['maxTemperature'] ?? 32).toDouble();

    if (temp < minTemp || temp > maxTemp) {
      debugPrint("Temperature $temp°C is out of bounds [$minTemp, $maxTemp]");
      return false;
    }
    currentTemp = temp;
    await _statusRef.update({'currentTemperature': temp});
    notifyListeners();
    return true;
  }

  Future<void> setMode(String newMode, {int duration = 30}) async {
    mode = newMode;
    await _statusRef.update({'mode': newMode});
    if(mode == 'timer'){
      currentTimer = duration;
      await _statusRef.update({'currentTimer': currentTimer});
    }
    notifyListeners();
  }

  Future<void> setLights(bool value) async {
    lightsOn = value;
    await _statusRef.update({'lightsOn': value});
    notifyListeners();
  }

  Future<void> setRelay(bool value) async {
    relayOn = value;
    await _statusRef.update({'relayOn': value});
    notifyListeners();
  }

  Future<void> setIdleFlag(String newFlag) async {
    idleFlag = newFlag;
    await _statusRef.update({'idleFlag': newFlag});
    notifyListeners();
  }

}