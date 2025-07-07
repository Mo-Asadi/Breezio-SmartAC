import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:breezio/widgets/barcode_scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class MaintenanceScreen extends StatefulWidget {
  final String deviceId;
  final String role;

  const MaintenanceScreen({super.key, required this.deviceId, required this.role});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  int totalHours = 0;
  int capacityHours = 250; // Prevent divide-by-zero
  bool loading = true;
  late DatabaseReference _configRef;
  late Stream<DatabaseEvent> _configStream;

  @override
  void initState() {
    super.initState();
    _configRef = _db.child('devices/${widget.deviceId}/maintenance');
    _listenToMaintenanceData();
  }

  void _listenToMaintenanceData() {
    _configStream = _configRef.onValue;
    _configStream.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          totalHours = data['totalHours'] ?? 0;
          capacityHours = data['capacityHours'] ?? 250;
          loading = false;
        });
      }
    });
  }

  Future<void> _resetMaintenance() async {
    final commandRef = _db.child('devices/${widget.deviceId}/command');
    await commandRef.set({
      'action': 'reset_maintenance',
      'uid': _uid,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🛠️ Maintenance reset command sent')),
    );
  }

  Future<void> _scanAndAddUser() async {
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
      final commandRef = _db.child('devices/${widget.deviceId}/command');
      await commandRef.set({
        'action': 'add_user',
        'uid': _uid,
        'new_uid': newUid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Added user $newUid')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final progress = (totalHours / capacityHours).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Total hours used: $totalHours / $capacityHours',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resetMaintenance,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Maintenance'),
            ),
            ElevatedButton.icon(
              onPressed: _scanAndAddUser,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Add New User'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _configRef.onDisconnect();
    super.dispose();
  }
}