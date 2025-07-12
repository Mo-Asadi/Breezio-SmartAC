import 'package:flutter/material.dart';
import 'package:breezio/widgets/sensors/dht11_sensor_card.dart';
import 'package:breezio/widgets/sensors/air_quality_card.dart';
import 'package:breezio/widgets/advice_widget.dart';
import 'package:breezio/widgets/weather_widget.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:breezio/providers/ac_status_provider.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  final String deviceId;
  const DashboardScreen({super.key, required this.deviceId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  @override
  void initState() {
    super.initState();
  }

  Stream<int?> _onlineStream() {
    final ref = FirebaseDatabase.instance
        .ref('devices/${widget.deviceId}/status/online');
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    });
  }

  Widget build(BuildContext context) {
    final acStatus = context.watch<ACStatusProvider>();
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'Breezing Through: ${acStatus.name}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  StreamBuilder<int?>(
                    stream: _onlineStream(),
                    builder: (context, snapshot) {
                      final online = snapshot.data;
                      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                      final isOnline = online != null && now - online < 45;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.circle,
                            color: isOnline ? Colors.green : Colors.red,
                            size: 10,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 14,
                              color: isOnline ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const WeatherWidget(),

            const SizedBox(height: 20),

            const AdviceWidget(),
            const SizedBox(height: 20),
            const Dht11SensorCard(),
            const SizedBox(height: 20),
            const AirQualityCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

  }
}
