import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class AirQualityWidget extends StatefulWidget {
  final String deviceId;
  final String databaseUrl;

  const AirQualityWidget({
    super.key,
    required this.deviceId,
    required this.databaseUrl,
  });

  @override
  State<AirQualityWidget> createState() => _AirQualityWidgetState();
}

class _AirQualityWidgetState extends State<AirQualityWidget> {
  late final DatabaseReference _deviceSensorsRef;

  int? _eco2;
  int? _tvoc;
  int? _aqi;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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
            _eco2 = data['eco2'] as int?;
            _tvoc = data['tvoc'] as int?;
            _aqi = data['aqi'] as int?;
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        setState(() {
          _eco2 = null;
          _tvoc = null;
          _aqi = null;
          _isLoading = false;
          _error = 'No air quality data available.';
        });
      }
    }, onError: (error) {
      setState(() {
        _error = 'Failed to load air quality data: ${error.toString()}';
        _isLoading = false;
      });
    });
  }

  // Helper function to get AQI color with 5-step scale
  Color _getAqiColor(int? aqi) {
    if (aqi == null) return Colors.grey;
    if (aqi <= 50) return Colors.green.shade700; // Excellent (Very Green)
    if (aqi <= 100) return Colors.green.shade400; // Moderate (Light Green)
    if (aqi <= 150) return Colors.yellow.shade700; // Unhealthy for sensitive groups (Yellow)
    if (aqi <= 200) return Colors.red.shade500; // Unhealthy (Red)
    if (aqi <= 300) return const Color.fromARGB(255, 140, 11, 2); // Unhealthy (Red)
    return const Color.fromARGB(255, 35, 4, 2); // Very Unhealthy / Hazardous (Very Red)
  }

  // Helper function to get AQI description (for info dialog)
  String _getAqiDescription(int? aqi) {
    if (aqi == null) return 'N/A';
    if (aqi <= 50) return 'Excellent';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  // Helper function to get eCO2 color with 5-step scale
  Color _getEco2Color(int? eco2) {
    if (eco2 == null) return Colors.grey;
    if (eco2 <= 400) return Colors.green.shade700; // Clean Fresh Air (Very Green)
    if (eco2 <= 800) return Colors.green.shade400; // Good/OK (Light Green)
    if (eco2 <= 1200) return Colors.yellow.shade700; // Getting Stale (Yellow)
    if (eco2 <= 1500) return Colors.red.shade400; // Needs Ventilation (Red)
    return Colors.red.shade700; // High/Very High (Very Red)
  }

  // Helper function to get eCO2 description (for info dialog)
  String _getEco2Description(int? eco2) {
    if (eco2 == null) return 'N/A';
    if (eco2 <= 400) return 'Clean Fresh Air';
    if (eco2 <= 1200) return 'OK, Getting Stale';
    return 'Needs Ventilation';
  }

  // Helper function to get TVOC color with 5-step scale
  Color _getTvocColor(int? tvoc) {
    if (tvoc == null) return Colors.grey;
    if (tvoc <= 50) return Colors.green.shade700; // Excellent (Very Green)
    if (tvoc <= 150) return Colors.green.shade400; // Good/Acceptable (Light Green)
    if (tvoc <= 300) return Colors.yellow.shade700; // Acceptable/Getting Polluted (Yellow)
    if (tvoc <= 450) return Colors.red.shade400; // Quite Polluted (Red)
    return Colors.red.shade700; // Very Polluted (Very Red)
  }

  // Helper function to get TVOC description (for info dialog)
  String _getTvocDescription(int? tvoc) {
    if (tvoc == null) return 'N/A';
    if (tvoc <= 150) return 'Excellent';
    if (tvoc <= 300) return 'Acceptable';
    return 'Quite Polluted';
  }

  // Function to show explanation dialog
  void _showExplanationDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Got It'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
              'Air Quality Readings:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 15),
            _buildAirQualityRow(
              context: context,
              label: 'eCO2',
              value: _eco2 != null ? '$_eco2 ppm' : 'N/A',
              color: _getEco2Color(_eco2),
              explanation: 'eCO2 (equivalent CO2) measures carbon dioxide levels. '
                  'Typical range: 400 – 2000 ppm.\n\n'
                  '400 ppm = Clean Fresh Air\n'
                  '800–1200 ppm = OK but getting stale\n'
                  '1500–2000 ppm = Needs Ventilation',
            ),
            const SizedBox(height: 8),
            _buildAirQualityRow(
              context: context,
              label: 'TVOC',
              value: _tvoc != null ? '$_tvoc ppb' : 'N/A',
              color: _getTvocColor(_tvoc),
              explanation: 'TVOC (Total Volatile Organic Compounds) are airborne chemicals that can be harmful. '
                  'Typical range: 0 – 600 ppb.\n\n'
                  '0–150 ppb = Excellent\n'
                  '150–300 ppb = Acceptable\n'
                  '300–600 ppb = Quite polluted, needs fresh air',
            ),
            const SizedBox(height: 8),
            _buildAirQualityRow(
              context: context,
              label: 'AQI',
              value: _aqi != null ? '$_aqi' : 'N/A',
              color: _getAqiColor(_aqi),
              explanation: 'The Air Quality Index (AQI) is a standard measure of daily air quality, '
                  'indicating how clean or polluted the air is and potential health effects. Lower values are better.\n\n'
                  'Standard scale: 0 – 500\n'
                  '0–50 = Excellent\n'
                  '51–100 = Moderate\n'
                  '101–150 = Unhealthy for sensitive groups\n'
                  '151–200 = Unhealthy\n'
                  '201–300 = Very Unhealthy\n'
                  '301–500 = Hazardous',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirQualityRow({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
    // Removed 'description' parameter as it's no longer displayed inline
    required String explanation,
  }) {
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
            '$label: $value', // Removed ($description) from here
            style: const TextStyle(fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, size: 20, color: Colors.grey),
          onPressed: () {
            _showExplanationDialog(context, '$label Explanation', explanation);
          },
        ),
      ],
    );
  }
}
