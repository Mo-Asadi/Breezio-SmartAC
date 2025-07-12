import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:breezio/providers/ac_status_provider.dart';
import 'package:breezio/providers/command_provider.dart';

class RemoteControllerScreen extends StatefulWidget {
  final String deviceId;

  const RemoteControllerScreen({super.key, required this.deviceId});

  @override
  State<RemoteControllerScreen> createState() => _RemoteControllerScreenState();
}

class _RemoteControllerScreenState extends State<RemoteControllerScreen> {
  final _user = FirebaseAuth.instance.currentUser!;
  final database = FirebaseDatabase.instance.ref();
  String deviceName = 'Breezio';


  @override
  void initState() {
    super.initState();
  }

  String formatTime(int time) {
    final hour = (time ~/ 100).toString().padLeft(2, '0');
    final minute = (time % 100).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void showScheduleDialog() async {
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final scheduleRef = database.child('devices/${widget.deviceId}/users/${_user.uid}/schedule');

    // Step 1: Load saved schedule if exists
    final snapshot = await scheduleRef.get();
    Map<String, dynamic> tempSchedule = {};

    if (snapshot.exists && snapshot.value is Map) {
      tempSchedule = Map<String, dynamic>.from(snapshot.value as Map);
    }

    // Step 2: Fill missing defaults
    for (final day in days) {
      tempSchedule[day.toLowerCase()] ??= {
        'active': false,
        'start': 800,
        'end': 1800,
      };
    }

    // Step 3: Show the dialog
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Set Weekly Schedule'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final key = day.toLowerCase();
                final dayData = Map<String, dynamic>.from(tempSchedule[key]);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: Text(day),
                      value: dayData['active'] ?? false,
                      onChanged: (val) => setState(() => tempSchedule[key]['active'] = val),
                    ),
                    if (dayData['active'] == true) ...[
                      Row(
                        children: [
                          const Text('Start:'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: formatTime(dayData['start'] ?? 800),
                              decoration: const InputDecoration(hintText: "HH:mm"),
                              onChanged: (val) {
                                final parts = val.split(':');
                                if (parts.length == 2) {
                                  final hour = int.tryParse(parts[0]) ?? 0;
                                  final minute = int.tryParse(parts[1]) ?? 0;
                                  tempSchedule[key]['start'] = hour * 100 + minute;
                                }
                              }
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('End:'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: formatTime(dayData['end'] ?? 1800),
                              decoration: const InputDecoration(hintText: "HH:mm"),
                              onChanged: (val) {
                                final parts = val.split(':');
                                if (parts.length == 2) {
                                  final hour = int.tryParse(parts[0]) ?? 0;
                                  final minute = int.tryParse(parts[1]) ?? 0;
                                  tempSchedule[key]['end'] = hour * 100 + minute;
                                }
                              }
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                    ],
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await scheduleRef.set(tempSchedule);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📅 Schedule saved')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  
  void showFavoriteDialog() async {
    final acStatus = context.read<ACStatusProvider>();
    final configRef = database.child('devices/${widget.deviceId}/config');
    final configSnapshot = await configRef.get();
    final config = configSnapshot.value as Map?;
    String favMode = acStatus.mode;
    double favTemp = acStatus.currentTemp.toDouble();
    bool favScent = acStatus.relayOn;
    bool favTheme = acStatus.lightsOn;
    double minTemp = (config!['minTemperature'] ?? 16).toDouble();
    double maxTemp = (config['maxTemperature'] ?? 32).toDouble();

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
                  spacing: 10,
                  children: ['regular', 'eco', 'motion', 'timer'].map((m) {
                    return ChoiceChip(
                      label: Text(m),
                      selected: favMode == m,
                      onSelected: (_) {
                        setState(() {
                          favMode = m;
                        });
                      },
                    );
                  }).toList(),
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
                onPressed: () async {
                  final favRef = database.child('devices/${widget.deviceId}/users/${_user.uid}/favorites');
                  await favRef.set({
                    'mode': favMode,
                    'temperature': favTemp,
                    'relayOn': favScent,
                    'lightsOn': favTheme,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⭐ Favorite settings saved')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void showTimerDurationDialog() {
    final commandProvider = context.read<CommandProvider>();
    final durations = [30, 60, 90, 120, 150, 180];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏱️ Select Timer Duration'),
        content: SizedBox(
          height: 200,
          child: ListView.builder(
            itemCount: durations.length,
            itemBuilder: (context, index) {
              final minutes = durations[index];
              return ListTile(
                title: Text('$minutes minutes'),
                onTap: () {
                  Navigator.pop(context);
                  commandProvider.sendCommand("set_mode", params: {'mode': 'timer', 'duration': minutes});
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final acStatus = context.watch<ACStatusProvider>();
    final commandProvider = context.read<CommandProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Breezing Through: ${acStatus.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Mode Selection
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['regular', 'eco', 'motion', 'timer'].map((mode) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(mode),
                      selected: acStatus.mode == mode,
                      onSelected: (_) {
                        if (mode == 'timer') {
                          showTimerDurationDialog();
                        } else {
                          commandProvider.sendCommand('set_mode', params: {'mode': mode});
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            if (acStatus.powered)
              Text('Current Temperature: ${acStatus.currentTemp}°C'),

            ElevatedButton(
              onPressed: (){
                if(acStatus.powered){
                  commandProvider.sendCommand('temp_up');
                }
                else{
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AC is not powered')),
                  );
                }
                },
              child: const Icon(Icons.arrow_upward),
            ),

            // Power, favorites, schedule
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: (){
                     commandProvider.sendCommand('apply_schedule');
                  },
                  onLongPress: showScheduleDialog,
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => commandProvider.sendCommand('switch_power'),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: acStatus.powered ? Colors.greenAccent : Colors.grey[300],
                      boxShadow: acStatus.powered
                          ? [const BoxShadow(color: Colors.green, blurRadius: 10)]
                          : [],
                    ),
                    child: const Icon(Icons.power_settings_new, size: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.star),
                  onPressed: (){ 
                    if(acStatus.powered){
                      commandProvider.sendCommand('apply_favorites');
                    }
                    else{
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('AC is not powered')),
                      );
                    }
                  },
                  onLongPress: showFavoriteDialog,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Temp down + LEDs + Scent
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.lightbulb),
                  color: acStatus.lightsOn ? Colors.yellowAccent : Colors.grey,
                  onPressed: () => commandProvider.sendCommand('switch_lights'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: (){
                    if(acStatus.powered){
                      commandProvider.sendCommand('temp_down');
                    }
                    else{
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('AC is not powered')),
                      );
                    }
                  },
                  child: const Icon(Icons.arrow_downward),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.local_florist),
                  color: acStatus.relayOn ? Colors.purpleAccent : Colors.grey,
                  onPressed: () => commandProvider.sendCommand('switch_relay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}