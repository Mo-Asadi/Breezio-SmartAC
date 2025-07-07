import 'package:flutter/material.dart';
import 'dart:math';

class AdviceWidget extends StatefulWidget {
  const AdviceWidget({super.key});

  @override
  State<AdviceWidget> createState() => _AdviceWidgetState();
}

class _AdviceWidgetState extends State<AdviceWidget> {
  final List<String> _adviceList = const [
    "For optimal comfort and energy savings, aim to keep your AC at 24°C .",
    "Clean your AC filters monthly to improve air quality and efficiency.",
    "Close windows and doors when your AC is running to prevent energy waste.",
    "Use your AC's 'Fan Only' mode on cooler days to circulate air without cooling.",
    "Regular maintenance can extend your AC's lifespan and prevent costly repairs.",
    "If your AC is blowing warm air, check the filter first, then consider professional help.",
    "For better sleep, set your AC to a slightly higher temperature at night.",
    "Shade your windows during the hottest part of the day to reduce AC load.",
    "Don't forget to check your outdoor unit for obstructions like leaves or debris.",
    "Ensure your AC unit is level to prevent drainage issues and improve efficiency.",
    "Use curtains or blinds to block direct sunlight and keep your room cooler.",
    "Turn off your AC when you leave a room for an extended period.",
    "Proper insulation can significantly reduce your AC's workload.",
    "If your AC smells musty, it might need a professional cleaning to prevent mold.",
  ];

  late int _currentAdviceIndex;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _currentAdviceIndex = _random.nextInt(_adviceList.length); // Start with a random advice
  }

  void _showNextAdvice() {
    setState(() {
      int newIndex = _random.nextInt(_adviceList.length);
      // Ensure the new advice is different from the current one if possible
      if (_adviceList.length > 1) {
        while (newIndex == _currentAdviceIndex) {
          newIndex = _random.nextInt(_adviceList.length);
        }
      }
      _currentAdviceIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Smart AC Tip:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              _adviceList[_currentAdviceIndex],
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center, // Center align the text for better appearance
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: _showNextAdvice,
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('New Tip'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.indigo, // Text color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
