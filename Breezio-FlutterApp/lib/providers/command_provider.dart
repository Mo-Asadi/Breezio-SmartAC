import 'package:breezio/providers/ac_maintenance_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'ac_status_provider.dart';

class CommandProvider extends ChangeNotifier {
  final String deviceId;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final ACStatusProvider? acStatus;
  final ACMaintenanceProvider? acMaintenance;
  

  CommandProvider(this.deviceId, {this.acStatus, this.acMaintenance});

  String? lastResultMessage;
  bool isBusy = false;

  final List<_CommandJob> _queue = [];

  Future<void> sendCommand(
    String action, {
    Map<String, dynamic>? params,
    VoidCallback? onSuccess,
    void Function(String error)? onError,
  }) async {
    _queue.add(
      _CommandJob(
        action: action,
        params: params,
        onSuccess: onSuccess,
        onError: onError,
      ),
    );
    _tryExecuteNext();
  }

  void _tryExecuteNext() {
    if (isBusy || _queue.isEmpty) return;

    final job = _queue.removeAt(0);
    _executeCommand(job);
  }

  void _executeCommand(_CommandJob job) async {
    isBusy = true;
    notifyListeners();

    final commandRef = _db.child('devices/$deviceId/command');
    final resultRef = _db.child('devices/$deviceId/result');

    // Check device online status
    final onlineSnapshot = await _db.child('devices/$deviceId/status/online').get();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final lastOnline = onlineSnapshot.value;
    final isOnline = (lastOnline is int || lastOnline is double)
        ? now - (lastOnline as num).toInt() < 60
        : false;

    if (!isOnline) {
      isBusy = false;
      notifyListeners();
      job.onError?.call('🚫 Device is offline');
      _tryExecuteNext();
      return;
    }

    // Build and send command
    final command = {
      'action': job.action,
      'uid': FirebaseAuth.instance.currentUser!.uid,
      ...?job.params,
    };

    if (job.action == 'apply_favorites') {
      await _applyFavorites();
      isBusy = false;
      notifyListeners();
      job.onSuccess?.call();
      _tryExecuteNext();
      return;
    }
    if (job.action == 'apply_schedule') {
      await _applySchedule();
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    await commandRef.remove();
    await resultRef.set('waiting');
    await Future.delayed(const Duration(milliseconds: 500));
    await commandRef.set(command);

    if (job.action == 'reset_device') {
      try {
        await _db.child('devices/$deviceId').remove();
        isBusy = false;
        notifyListeners();
        job.onSuccess?.call();
      } catch (e) {
        isBusy = false;
        notifyListeners();
        job.onError?.call('❌ Failed to reset device: $e');
      }
      _tryExecuteNext();
      return;
    }

    late StreamSubscription<DatabaseEvent> sub;
    await Future.delayed(const Duration(milliseconds: 500));
    sub = resultRef.onValue.listen((event) async {
      final result = event.snapshot.value;
      if (result is String && result == 'Success') {
        lastResultMessage = result;
        sub.cancel();
        await commandRef.remove();
        await resultRef.remove();

        // Update status if needed
        switch (job.action) {
          case 'switch_power':
            acStatus?.setPower(!(acStatus?.powered ?? false));
            break;
          case 'switch_lights':
            acStatus?.setLights(!(acStatus?.lightsOn ?? false));
            break;
          case 'switch_relay':
            acStatus?.setRelay(!(acStatus?.relayOn ?? false));
            break;
          case 'temp_up':
            acStatus?.setTemperature((acStatus?.currentTemp ?? 24) + 1);
            break;
          case 'temp_down':
            acStatus?.setTemperature((acStatus?.currentTemp ?? 24) - 1);
            break;
          case 'reset_maintenance':
            acMaintenance?.setTotalHours(0.0);
            break;
          case 'set_mode':
            if (job.params?['mode'] is String) {
              acStatus?.setMode(job.params!['mode'], duration: job.params?['duration'] ?? 30);
            }
            break;
        }

        isBusy = false;
        notifyListeners();
        job.onSuccess?.call();
        _tryExecuteNext();
      }
    });

    Future.delayed(const Duration(seconds: 6), () async {
      if (isBusy) {
        sub.cancel();
        lastResultMessage = '⏱️ Timeout waiting for device response';
        isBusy = false;
        notifyListeners();
        job.onError?.call(lastResultMessage!);
        _tryExecuteNext();
      }
    });
  }

  Future<void> _applyFavorites() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final favRef = _db.child('devices/$deviceId/users/$uid/favorites');
    final snapshot = await favRef.get();

    if (!snapshot.exists || snapshot.value is! Map){
      lastResultMessage = '⚠️ No saved favorites found';
      notifyListeners();
      return;
    }
    final fav = Map<String, dynamic>.from(snapshot.value as Map);

    final String? favMode = fav['mode'];
    final double? favTemp = (fav['temperature'] as num?)?.toDouble();
    final bool? favScent = fav['relayOn'];
    final bool? favTheme = fav['lightsOn'];

    // 1. Apply temperature difference
    final double currentTemp = acStatus?.currentTemp.toDouble() ?? 24;
    if (favTemp != null) {
      final diff = favTemp - currentTemp;
      final tempAction = diff > 0 ? 'temp_up' : 'temp_down';
      for (int i = 0; i < diff.abs().round(); i++) {
        _queue.add(_CommandJob(action: tempAction));
      }
    }

    // 2. Apply mode if different
    if (favMode != null && favMode != acStatus?.mode) {
      _queue.add(
        _CommandJob(
          action: 'set_mode',
          params: {'mode': favMode},
        ),
      );
    }

    // 3. Apply scent relay
    if (favScent != null && favScent != acStatus?.relayOn) {
      _queue.add(_CommandJob(action: 'switch_relay'));
    }

    // 4. Apply theme lights
    if (favTheme != null && favTheme != acStatus?.lightsOn) {
      _queue.add(_CommandJob(action: 'switch_lights'));
    }

    _tryExecuteNext(); // Start the queue if nothing is running
  }

  Future<void> _applySchedule() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userScheduleRef = _db.child('devices/$deviceId/users/$uid/schedule');
    final globalScheduleRef = _db.child('devices/$deviceId/schedule');

    final snapshot = await userScheduleRef.get();

    if (!snapshot.exists || snapshot.value is! Map) {
      lastResultMessage = '⚠️ No saved schedule found';
      notifyListeners();
      return;
    }

    await globalScheduleRef.set(snapshot.value);
    lastResultMessage = '✅ Schedule applied successfully';
    notifyListeners();
  }
}

class _CommandJob {
  final String action;
  final Map<String, dynamic>? params;
  final VoidCallback? onSuccess;
  final void Function(String error)? onError;

  _CommandJob({
    required this.action,
    this.params,
    this.onSuccess,
    this.onError,
  });
}