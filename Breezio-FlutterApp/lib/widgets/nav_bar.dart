import 'package:breezio/screens/dashboard_screen.dart';
import 'package:breezio/screens/maintenance_screen.dart';
import 'package:breezio/screens/remote_controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:breezio/screens/ac_setup_screen.dart';
import 'package:breezio/screens/login_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';



class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  int _selectedIndex = 0;
  String? _selectedDeviceId;
  String? _selectedDeviceRole;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: dotenv.env['DATABASE_URL'],
  ).ref("devices");
  Map<String, String> _devices = {};
  bool _loadingDevices = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  List<Widget> _buildScreens() {
    if (_selectedDeviceId == null) return [];

    final dashboard = DashboardScreen(
      deviceId: _selectedDeviceId!,
      role: _selectedDeviceRole!,
    );
    final remote = RemoteControllerScreen(
      deviceId: _selectedDeviceId!,
      role: _selectedDeviceRole!,
    );
    final maintenance = MaintenanceScreen(
      deviceId: _selectedDeviceId!,
      role: _selectedDeviceRole!,
    );

    return _selectedDeviceRole == 'admin'
        ? [dashboard, remote, maintenance]
        : [dashboard, remote];
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    return _selectedDeviceRole == 'admin'
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.ac_unit), label: 'Remote'),
            BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintenance'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.ac_unit), label: 'Remote'),
          ];
  }

  Future<void> _loadDevices() async {
    final snapshot = await _db.get();
    final data = snapshot.value as Map?;

    if (data == null) {
      setState(() {
        _loadingDevices = false;
        _devices = {};
      });
      return;
    }

    final Map<String, String> result = {};
    data.forEach((deviceId, deviceData) {
      final authUsers = (deviceData as Map)['users'] as Map?;
      final userEntry = authUsers?[_uid] as Map?;
      final role = userEntry?['role'];
      if (role != null) {
        result[deviceId] = role;
      }
    });

    setState(() {
      _devices = result;
      _loadingDevices = false;
    });
  }

  void _onAddDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AcSetupScreen()),
    );
  }

  void _onDeviceSelected(String deviceId, String role) {
    setState(() {
      _selectedDeviceId = deviceId;
      _selectedDeviceRole = role;
    });
    Navigator.pop(context); // Close bottom sheet
  }

  Widget _buildDeviceList() {
    if (_loadingDevices) {
      return const Center(child: CircularProgressIndicator());
    }

    final deviceList = _devices.entries.map((entry) => ListTile(
          leading: const Icon(Icons.devices),
          title: Text('Device ${entry.key}'),
          subtitle: Text('Role: ${entry.value}'),
          onTap: () => _onDeviceSelected(entry.key, entry.value),
        )).toList();

    return ListView(
      shrinkWrap: true,
      children: [
        if (_devices.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No devices available.'),
          )),
        ...deviceList,
        const Divider(),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add New Device'),
          onTap: _onAddDevice,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()),);
            }
          },
        ),
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () async {
              await _loadDevices(); // 👈 Ensure you refresh the list
              if (!context.mounted) return;

              showModalBottomSheet(
                context: context,
                builder: (_) => SizedBox(
                  height: 400,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildDeviceList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _selectedDeviceId == null
      ? const Center(child: Text("Select a device to continue"))
      : IndexedStack(
          index: _selectedIndex,
          children: _buildScreens(),
        ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: _buildNavItems(),
      ),
    );
  }
}