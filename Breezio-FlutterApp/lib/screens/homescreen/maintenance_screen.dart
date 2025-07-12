import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:breezio/widgets/barcode_scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:breezio/providers/ac_maintenance_provider.dart';
import 'package:breezio/providers/command_provider.dart';
import 'package:provider/provider.dart';

class MaintenanceScreen extends StatefulWidget {
  final String deviceId;

  const MaintenanceScreen({super.key, required this.deviceId});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  void _sendMaintenanceReset(CommandProvider commandProvider) {
    commandProvider.sendCommand(
      'reset_maintenance',
      onSuccess: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🛠️ Maintenance reset command sent')),
        );
      },
      onError: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      },
    );
  }

  void _sendDeviceReset(CommandProvider commandProvider) {
    commandProvider.sendCommand(
      'reset_device',
      onSuccess: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔄 Reset device command sent')),
        );
      },
      onError: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      },
    );
  }

  void _showAuthorizedUsers(String deviceId) async {
    final usersRef = FirebaseDatabase.instance.ref('devices/$deviceId/users');
    final snapshot = await usersRef.get();

    if (!snapshot.exists || snapshot.value is! Map) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authorized users found')),
      );
      return;
    }

    final usersMap = Map<String, dynamic>.from(snapshot.value as Map);
    final excludedUids = {'system', 'scheduler', _uid};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authorized Users'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: usersMap.entries
                .where((entry) => !excludedUids.contains(entry.key))
                .map((entry) {
              final uid = entry.key;
              final role = (entry.value as Map?)?['role'] ?? 'unknown';

              return ListTile(
                title: Text('UID: $uid'),
                subtitle: Text('Role: $role'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await usersRef.child(uid).remove();
                    if (mounted) Navigator.pop(context);
                    _showAuthorizedUsers(deviceId); // refresh
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Removed user $uid')),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  Future<void> _scanAndAddUser(String deviceId) async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to scan QR codes')),
        );
        return;
      }
    }

    final newUid = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (newUid is String && newUid.isNotEmpty) {
      final usersRef = FirebaseDatabase.instance.ref('devices/$deviceId/users/$newUid');
      await usersRef.set({
        'role': 'user',
        'favorites': {},
        'schedule': {},
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Added user $newUid')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final acMaintenance = context.watch<ACMaintenanceProvider>();
    final commandProvider = context.read<CommandProvider>();

    final progress = (acMaintenance.totalHours / acMaintenance.capacityHours).clamp(0.0, 1.0);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Total hours used: ${acMaintenance.totalHours} / ${acMaintenance.capacityHours}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _sendMaintenanceReset(commandProvider),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Maintenance'),
            ),
            ElevatedButton.icon(
              onPressed: () => _scanAndAddUser(widget.deviceId),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Add New User'),
            ),
            ElevatedButton.icon(
              onPressed: () => _sendDeviceReset(commandProvider),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Device'),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAuthorizedUsers(widget.deviceId),
              icon: const Icon(Icons.people),
              label: const Text('View Authorized Users'),
            ),
          ],
        ),
      ),
    );
  }
}