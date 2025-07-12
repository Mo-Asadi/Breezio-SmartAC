import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breezio/providers/sensor_data_provider.dart';

class Dht11SensorCard extends StatelessWidget {
  const Dht11SensorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorDataProvider>();

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
                  'Temperature: ${sensor.roomTemp.toStringAsFixed(1)} °C',
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
                  'Humidity: ${sensor.roomHumidity.toStringAsFixed(0)} %',
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