import 'package:flutter/material.dart';
import 'package:breezio/widgets/dh11_widget.dart';
import 'package:breezio/widgets/air_quality_widget.dart';
import 'package:breezio/widgets/advice_widget.dart';
import 'package:breezio/widgets/weather_widget.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class DashboardScreen extends StatefulWidget {
  final String deviceId;
  final String role;
  const DashboardScreen({super.key, required this.deviceId, required this.role});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _databaseUrl = dotenv.env['DATABASE_URL'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart AC Dashboard'),
        actions: [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WeatherWidget(),
            const SizedBox(height: 20),

            Text(
              'Device ID: ${widget.deviceId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            const AdviceWidget(),
            const SizedBox(height: 20),

            Dh11Widget(
              deviceId: widget.deviceId,
              databaseUrl: _databaseUrl!,
            ),
            const SizedBox(height: 20),

            AirQualityWidget(
              deviceId: widget.deviceId,
              databaseUrl: _databaseUrl,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

  }
}
