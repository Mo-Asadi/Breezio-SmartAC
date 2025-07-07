import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class Dh11Widget extends StatefulWidget {
  final String deviceId;
  final String databaseUrl;

  const Dh11Widget({
    super.key,
    required this.deviceId,
    required this.databaseUrl,
  });

  @override
  State<Dh11Widget> createState() => _Dh11WidgetState();
}

class _Dh11WidgetState extends State<Dh11Widget> {
  late final DatabaseReference _deviceSensorsRef;

  double? _temperature;
  int? _humidity;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize the database reference to the specific device's sensors node
    _deviceSensorsRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: widget.databaseUrl,
    ).ref('devices/${widget.deviceId}/sensors');

    _listenToSensorData();
  }

  void _listenToSensorData() {
    // Listen for real-time changes to the sensor data
    _deviceSensorsRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          setState(() {
            _temperature = (data['roomTemperature'] as num?)?.toDouble();
            _humidity = data['roomHumidity'] as int?;
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        setState(() {
          _temperature = null;
          _humidity = null;
          _isLoading = false;
          _error = 'No sensor data available.';
        });
      }
    }, onError: (error) {
      setState(() {
        _error = 'Failed to load sensor data: ${error.toString()}';
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sensor Readings (DHT11):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.thermostat, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Temperature: ${_temperature?.toStringAsFixed(1) ?? 'N/A'} °C',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Humidity: ${_humidity ?? 'N/A'} %',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
