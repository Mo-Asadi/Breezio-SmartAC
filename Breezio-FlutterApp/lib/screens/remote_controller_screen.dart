import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RemoteControllerScreen extends StatefulWidget {
  final String deviceId;
  final String role;

  const RemoteControllerScreen({super.key, required this.deviceId, required this.role});

  @override
  State<RemoteControllerScreen> createState() => _RemoteControllerScreenState();
}

class _RemoteControllerScreenState extends State<RemoteControllerScreen> {
  final _user = FirebaseAuth.instance.currentUser!;
  final database = FirebaseDatabase.instance.ref();

  bool acOn = false;
  String mode = 'regular';
  bool ledOn = false;
  bool scentOn = false;
  int? acTemp;

  @override
  void initState() {
    super.initState();
    _listenToACStatus();
  }

  void _listenToACStatus() {
    final statusRef = database.child('devices/${widget.deviceId}/status');
    statusRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        acOn = data['powered'] == true;
        acTemp = data['currentTemperature'];
        mode = data['mode'] ?? mode;
        ledOn = data['lightsOn'] == true;
        scentOn = data['relayOn'] == true;
      });
    });
  }

  void sendCommand(String action, {
    String? newUid,
    String? favMode,
    double? favTemp,
    bool? favScent,
    bool? favTheme,
    String? mode,
  }) async {
    final commandRef = database.child('devices/${widget.deviceId}/command');

    final snapshot = await commandRef.get();
    final currentCommand = snapshot.value;

    if (currentCommand is! String && currentCommand != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Device is busy, please wait...')),
      );
      return;
    }

    final command = {
      'action': action,
      'uid': _user.uid,
      if (newUid != null) 'new_uid': newUid,
      if (favMode != null) 'favMode': favMode,
      if (favTemp != null) 'favTemp': favTemp,
      if (favScent != null) 'favScent': favScent,
      if (favTheme != null) 'favTheme': favTheme,
      if (mode != null) 'mode': mode,
    };

    await commandRef.set(command);
  }

  void sendFavorite() {
    sendCommand('apply_favorites');
  }

  void showFavoriteDialog() async {
    String favMode = mode;
    double favTemp = acTemp?.toDouble() ?? 24;
    bool favScent = scentOn;
    bool favTheme = ledOn;
    double minTemp = 16;
    double maxTemp = 32;

    // Fetch limits from RTDB
    final configRef = database.child('devices/${widget.deviceId}/config');
    final configSnapshot = await configRef.get();
    final config = configSnapshot.value as Map?;
    if (config != null) {
      minTemp = (config['minTemperature'] ?? 16).toDouble();
      maxTemp = (config['maxTemperature'] ?? 32).toDouble();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Set Favorite Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Temp: ${favTemp.toInt()}°C'),
                Slider(
                  value: favTemp.clamp(minTemp, maxTemp),
                  min: minTemp,
                  max: maxTemp,
                  divisions: (maxTemp - minTemp).toInt(),
                  label: favTemp.toInt().toString(),
                  onChanged: (val) => setState(() => favTemp = val),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['regular', 'eco', 'motion', 'timer']
                      .map((m) => ChoiceChip(
                            label: Text(m),
                            selected: favMode == m,
                            onSelected: (_) => setState(() => favMode = m),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('LED Strip'),
                  value: favTheme,
                  onChanged: (val) => setState(() => favTheme = val),
                ),
                SwitchListTile(
                  title: const Text('Scent Diffuser'),
                  value: favScent,
                  onChanged: (val) => setState(() => favScent = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  sendCommand(
                    'set_favorites',
                    favMode: favMode,
                    favTemp: favTemp,
                    favScent: favScent,
                    favTheme: favTheme,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Control Device ${widget.deviceId}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (acOn && acTemp != null)
              Text('🌡️ Current Temperature Set: $acTemp', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),

            Wrap(
              spacing: 10,
              children: [
                ElevatedButton(
                  onPressed: () => sendCommand('switch_power'),
                  child: Text('Power'),
                ),
                ElevatedButton(
                  onPressed: () => sendCommand('temp_up'),
                  child: const Text('+'),
                ),
                ElevatedButton(
                  onPressed: () => sendCommand('temp_down'),
                  child: const Text('-'),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Text('Mode:'),
            Wrap(
              spacing: 10,
              children: ['regular', 'eco', 'motion', 'timer']
                  .map((m) => ChoiceChip(
                        label: Text(m),
                        selected: mode == m,
                        onSelected: (_) => sendCommand("mode", mode: m),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text('LED Strip'),
                    value: ledOn,
                    onChanged: (_) => sendCommand('switch_lights'),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Scent Diffuser'),
                    value: scentOn,
                    onChanged: (_) => sendCommand('switch_relay'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            Center(
              child: GestureDetector(
                onTap: sendFavorite,
                onLongPress: showFavoriteDialog,
                child: const Icon(Icons.star, size: 40, color: Colors.amber),
              ),
            ),
          ],
        ),
      ),
    );
  }
}