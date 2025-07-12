import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breezio/providers/sensor_data_provider.dart';

class AirQualityCard extends StatelessWidget {
  const AirQualityCard({super.key});

  Color _getAqiColor(int aqi) {
    if (aqi <= 50) return Colors.green.shade700;
    if (aqi <= 100) return Colors.green.shade400;
    if (aqi <= 150) return Colors.yellow.shade700;
    if (aqi <= 200) return Colors.red.shade400;
    if (aqi <= 300) return const Color.fromARGB(255, 140, 11, 2);
    return const Color.fromARGB(255, 35, 4, 2);
  }

  Color _getEco2Color(int eco2) {
    if (eco2 <= 400) return Colors.green.shade700;
    if (eco2 <= 800) return Colors.green.shade400;
    if (eco2 <= 1200) return Colors.yellow.shade700;
    if (eco2 <= 1500) return Colors.red.shade400;
    return Colors.red.shade700;
  }

  Color _getTvocColor(int tvoc) {
    if (tvoc <= 50) return Colors.green.shade700;
    if (tvoc <= 150) return Colors.green.shade400;
    if (tvoc <= 300) return Colors.yellow.shade700;
    if (tvoc <= 450) return Colors.red.shade400;
    return Colors.red.shade700;
  }

  Widget _buildRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

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
              'Air Quality Readings:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _buildRow('eCO2', '${sensor.eco2} ppm', _getEco2Color(sensor.eco2)),
            const SizedBox(height: 8),
            _buildRow('TVOC', '${sensor.tvoc} ppb', _getTvocColor(sensor.tvoc)),
            const SizedBox(height: 8),
            _buildRow('AQI', '${sensor.aqi}', _getAqiColor(sensor.aqi)),
          ],
        ),
      ),
    );
  }
}