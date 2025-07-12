import 'package:breezio/screens/homescreen/dashboard_screen.dart';
import 'package:breezio/screens/homescreen/maintenance_screen.dart';
import 'package:breezio/screens/homescreen/remote_controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:breezio/screens/authentication&onboarding/ac_setup_screen.dart';
import 'package:breezio/screens/authentication&onboarding/login_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:breezio/providers/sensor_data_provider.dart';
import 'package:breezio/providers/ac_status_provider.dart';
import 'package:breezio/providers/ac_maintenance_provider.dart';
import 'package:breezio/providers/command_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _selectedDeviceId;
  String? _selectedDeviceRole;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: dotenv.env['DATABASE_URL'],
  ).ref("devices");
  Map<String, Map<String, dynamic>> _devices = {};
  bool _loadingDevices = true;
  List<Widget> _cachedScreens = [];
  List<BottomNavigationBarItem> _cachedNavItems = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<List<Widget>> _prepareScreens() async {
    if (_selectedDeviceId == null) return [];
    String? role = await getUserRole(_selectedDeviceId);
    _selectedDeviceRole = role;

    final dashboard = MultiProvider(
      providers: [
        ChangeNotifierProvider( create: (_) => SensorDataProvider(_selectedDeviceId!)),
        ChangeNotifierProvider(create: (_) => ACStatusProvider(_selectedDeviceId!)),
      ],
      child: DashboardScreen(deviceId: _selectedDeviceId!),
    );

    final remote = MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ACStatusProvider(_selectedDeviceId!)),
        ChangeNotifierProvider(create: (context) => CommandProvider(_selectedDeviceId!, acStatus: context.read<ACStatusProvider>(),),),
      ],
      child: RemoteControllerScreen(deviceId: _selectedDeviceId!),
    );

    final maintenance = MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ACMaintenanceProvider(_selectedDeviceId!)),
        ChangeNotifierProvider(create: (_) => ACStatusProvider(_selectedDeviceId!)),
        ChangeNotifierProvider(create: (context) => CommandProvider(_selectedDeviceId!, acStatus: context.read<ACStatusProvider>(), acMaintenance: context.read<ACMaintenanceProvider>()),),
      ],
      child: MaintenanceScreen(deviceId: _selectedDeviceId!),
    );

    return role == 'admin' ? [dashboard, remote, maintenance] : [dashboard, remote];
  }

  Future<List<BottomNavigationBarItem>> _buildNavItems() async {
    String? role = await getUserRole(_selectedDeviceId);
    _selectedDeviceRole = role;
    return role == 'admin'
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_remote), label: 'Remote'),
            BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Maintenance'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_remote), label: 'Remote'),
          ];
  }

  Future<String?> getUserRole(String? deviceId) async {
    final dbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: dotenv.env['DATABASE_URL'],
    ).ref("devices/$deviceId/users/$_uid/role");

    final snapshot = await dbRef.get();

    if (snapshot.exists) {
      return snapshot.value as String;
    } else {
      return null;
    }
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

    final Map<String, Map<String, dynamic>> result = {};

    for (final entry in data.entries) {
      final deviceId = entry.key;
      final deviceData = entry.value as Map?;
      final users = deviceData?['users'] as Map?;
      final status = deviceData?['status'] as Map?;
      final userEntry = users?[_uid] as Map?;
      final role = userEntry?['role'];
      final name = status?['name'] ?? "BreezioAC";
      final lastOnline = (deviceData?['status'] as Map?)?['online'] ?? 0;

      if (role != null) {
        result[deviceId] = {
          'name': name,
          'role': role,
          'online': lastOnline,
        };
      }
    }

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

  Future<void> _onDeviceSelected(String deviceId, String role) async {
    _selectedDeviceId = deviceId;
    _selectedDeviceRole = role;

    _cachedScreens = await _prepareScreens();
    _cachedNavItems = await _buildNavItems();

    setState(() {}); // trigger UI rebuild
    Navigator.pop(context);
  }

  Stream<int?> _onlineStream(String deviceId) {
    final ref = FirebaseDatabase.instance
        .ref("devices/$deviceId/status/online");
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    });
  }

  Widget _buildDeviceList() {
    if (_loadingDevices) {
      return const Center(child: CircularProgressIndicator());
    }

    final deviceList = _devices.entries.map((entry) {
      final deviceId = entry.key;
      final name = entry.value['name'] ?? deviceId;
      final role = entry.value['role'] ?? 'user';

      return ListTile(
        leading: Stack(
          children: [
            const Icon(Icons.devices),
            Positioned(
              right: 0,
              top: 0,
              child: StreamBuilder<int?>(
                stream: _onlineStream(deviceId),
                builder: (context, snapshot) {
                  final online = snapshot.data;
                  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                  final isOnline = online != null && now - online < 45;
                  return Icon(
                    Icons.circle,
                    size: 10,
                    color: isOnline ? Colors.green : Colors.red,
                  );
                },
              ),
            ),
          ],
        ),
        title: Text(name),
        subtitle: Text('Role: $role'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editDeviceName(deviceId),
        ),
        onTap: () => _onDeviceSelected(deviceId, role),
      );
    }).toList();

    return ListView(
      shrinkWrap: true,
      children: [
        if (_devices.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No devices available.'),
            ),
          ),
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

  void _editDeviceName(String deviceId) {
    final TextEditingController controller = TextEditingController(
      text: _devices[deviceId]?['name'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new device name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await _db.child('$deviceId/status/name').set(newName);
                await _loadDevices();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool navReady = _selectedDeviceId != null &&
                          _cachedNavItems.length >= 2 &&
                          _cachedScreens.length >= 2;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          },
        ),
        title: Text(
          _selectedDeviceRole == 'admin'
              ? ['Dashboard', 'Remote Control', 'Maintenance'][_selectedIndex]
              : ['Dashboard', 'Remote Control'][_selectedIndex],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () async {
              await _loadDevices();
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
      body: navReady
          ? IndexedStack(
              index: _selectedIndex,
              children: _cachedScreens,
            )
          : const Center(child: Text("Select a device to continue")),
      bottomNavigationBar: navReady
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              items: _cachedNavItems,
            )
          : null,
    );
  }
}