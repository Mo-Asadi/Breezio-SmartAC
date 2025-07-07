import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String _temperature = 'N/A';
  String _condition = 'N/A';
  IconData _conditionIcon = Icons.help_outline;
  Color _conditionIconColor = Colors.grey;
  String? _error;
  bool _isLoading = true;

  final _apiKey = dotenv.env['OPENWEATHER_API_KEY'];

  final List<String> _cities = const [
    'Jerusalem',
    'Tel Aviv-Yafo',
    'Haifa',
    'Rishon LeZion',
    'Petah Tikva',
    'Ashdod',
    'Netanya',
    'Beer Sheva',
    'Bnei Brak',
    'Holon',
  ];

  late String _selectedCity;

  @override
  void initState() {
    super.initState();
    _selectedCity = _cities[0];
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.openweathermap.org/data/2.5/weather?q=$_selectedCity&units=metric&appid=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _temperature = '${data['main']['temp'].round()}°C';
          _condition = data['weather'][0]['description'];
          
          final iconData = _getWeatherIcon(data['weather'][0]['id']);
          _conditionIcon = iconData.key;
          _conditionIconColor = iconData.value;

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load weather: ${response.statusCode} - ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching weather: $e';
        _isLoading = false;
      });
    }
  }

  // Helper function to map OpenWeatherMap weather IDs to Flutter Icons and Colors
  MapEntry<IconData, Color> _getWeatherIcon(int weatherId) {
    if (weatherId >= 200 && weatherId < 300) {
      return const MapEntry(Icons.thunderstorm, Colors.indigo); // Thunderstorm
    } else if (weatherId >= 300 && weatherId < 400) {
      return const MapEntry(Icons.grain, Colors.lightBlue); // Drizzle
    } else if (weatherId >= 500 && weatherId < 600) {
      return const MapEntry(Icons.umbrella, Colors.blue); // Rain
    } else if (weatherId >= 600 && weatherId < 700) {
      return const MapEntry(Icons.ac_unit, Colors.white); // Snow
    } else if (weatherId >= 700 && weatherId < 800) {
      return const MapEntry(Icons.cloud, Colors.grey); // Atmosphere (mist, smoke, etc.)
    } else if (weatherId == 800) {
      return const MapEntry(Icons.wb_sunny, Colors.amber); // Clear sky
    } else if (weatherId > 800 && weatherId < 900) {
      return const MapEntry(Icons.cloud, Colors.white); // Clouds
    } else {
      return const MapEntry(Icons.help_outline, Colors.grey); // Default for unknown
    }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Weather:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                DropdownButton<String>(
                  value: _selectedCity,
                  icon: const Icon(Icons.arrow_downward),
                  elevation: 16,
                  style: const TextStyle(color: Colors.indigo, fontSize: 16),
                  underline: Container(
                    height: 2,
                    color: Colors.indigoAccent,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCity = newValue!;
                      _fetchWeatherData();
                    });
                  },
                  items: _cities.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(_conditionIcon, size: 40, color: _conditionIconColor),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedCity,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _temperature,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _condition,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
