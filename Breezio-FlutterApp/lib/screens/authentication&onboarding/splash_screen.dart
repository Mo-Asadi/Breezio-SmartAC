import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import "package:breezio/screens/authentication&onboarding/login_screen.dart";
import 'package:breezio/widgets/navigation/home_screen_nav.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:breezio/main.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void listenToIdleFlag(String mac, String name) {
    final idleRef = FirebaseDatabase.instance.ref('devices/$mac/status/idleFlag');
    final resultRef = FirebaseDatabase.instance.ref('devices/$mac/result');
    idleRef.onValue.listen((event) {
      final flag = event.snapshot.value;
      if (flag == 'user_prompt') {
        if (navigatorKey.currentContext != null) {
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('No Motion Detected'),
              content: Text('Device $name is on and detected no motion for 30 minutes.'),
              actions: [
                TextButton(
                  onPressed: () async{
                    final commandRef = FirebaseDatabase.instance.ref('devices/$mac/command');
                    await commandRef.remove();
                    await resultRef.remove();
                    await Future.delayed(const Duration(milliseconds: 500));
                    await commandRef.set({
                      'action': 'ignore_motion',
                      'uid': FirebaseAuth.instance.currentUser?.uid,
                    });

                    // ✅ Reset idleFlag to "active"
                    idleRef.set('active');

                    Navigator.of(context).pop();
                  },
                  child: const Text('Continue'),
                ),
                ElevatedButton(
                  onPressed: () async{
                    final statusRef = FirebaseDatabase.instance.ref('devices/$mac/status/powered');
                    final commandRef = FirebaseDatabase.instance.ref('devices/$mac/command');
                    bool acIsPowered = true;
                    final snapshot = await statusRef.get();
                    if (snapshot.exists) {
                        acIsPowered = (snapshot.value is bool && snapshot.value == true);
                    }
                    await commandRef.remove();
                    await resultRef.remove();
                    await Future.delayed(const Duration(milliseconds: 500));
                    if(acIsPowered){
                      commandRef.set({
                        'action': 'switch_power',
                        'uid': FirebaseAuth.instance.currentUser?.uid,
                      });
                      // ✅ Reset idleFlag to "active"
                      idleRef.set('active');
                      late StreamSubscription<DatabaseEvent> sub;
                      await Future.delayed(const Duration(milliseconds: 500));
                      sub = resultRef.onValue.listen((event) async {
                        final result = event.snapshot.value;
                        if (result is String && result == 'Success') {
                          sub.cancel();
                          await commandRef.remove();
                          await resultRef.remove();
                          final statusRef = FirebaseDatabase.instance.ref('devices/$mac/status/powered');
                          statusRef.set(false);
                        }});
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Turn Off'),
                ),
              ],
            ),
          );
        } else {
          // Fallback to local notification if context isn't available
          showFlutterNotification(
            title: 'No Motion Detected',
            body: 'Device $mac is on and detected no motion for 30 minutes.',
            payload: mac,
          );
        }
      }
    });
  }

  void listenToBuzzFlag(String mac, String name) {
    final buzzRef = FirebaseDatabase.instance.ref('devices/$mac/status/maintenanceFlag');
    buzzRef.onValue.listen((event) {
      final flag = event.snapshot.value;
      if (flag == true) {
        if (navigatorKey.currentContext != null) {
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Maintenance Required'),
              content: Text('Device $name\'s Maintenance Is Due.'),
              actions: [
                TextButton(
                  onPressed: () async{
                    await buzzRef.remove();
                    await Future.delayed(const Duration(milliseconds: 500));
                    await buzzRef.set(false);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
        } else {
          // Fallback to local notification if context isn't available
          showFlutterNotification(
            title: 'Maintenance Required',
            body: 'Device $name\'s Maintenance Is Due.',
            payload: mac,
          );
        }
      }
    });
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate loading

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final devicesRef = FirebaseDatabase.instance.ref('devices');
      devicesRef.once().then((snapshot) {
        final data = snapshot.snapshot.value as Map?;
        if (data != null) {
          for (final entry in data.entries) {
            final mac = entry.key;
            final deviceData = entry.value as Map?;
            final statusData = deviceData?['status'] as Map?;
            final name = statusData?["name"] ?? mac;
            final users = deviceData?['users'] as Map?;
            if (users != null && users.containsKey(user.uid)) {
              listenToIdleFlag(mac, name);
              listenToBuzzFlag(mac, name);
            }
          }
        }
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

