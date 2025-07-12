import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:breezio/screens/authentication&onboarding/splash_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();

  // Local notification plugin setup
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: onNotificationTap,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Breezio',
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Local notification tap handler
void onNotificationTap(NotificationResponse response) {
  final mac = response.payload;
  if (mac == null || navigatorKey.currentContext == null) return;

  showDialog(
    context: navigatorKey.currentContext!,
    builder: (context) => AlertDialog(
      title: const Text('No Motion Detected'),
      content: Text('Device $mac is on and detected no motion for 30 minutes.'),
      actions: [
        TextButton(
          onPressed: () {
            FirebaseDatabase.instance.ref('devices/$mac/command').set({
              'action': 'ignore_motion',
              'uid': FirebaseAuth.instance.currentUser?.uid,
            });
            Navigator.of(context).pop();
          },
          child: const Text('Continue'),
        ),
        ElevatedButton(
          onPressed: () {
            FirebaseDatabase.instance.ref('devices/$mac/command').set({
              'action': 'switch_power',
              'uid': FirebaseAuth.instance.currentUser?.uid,
            });
            Navigator.of(context).pop();
          },
          child: const Text('Turn Off'),
        ),
      ],
    ),
  );
}

void handleNotificationNavigation(String? deviceId, String? role, String? targetUid, [String? contextType]) {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (deviceId == null || role == null || targetUid == null) return;
  if (currentUid != targetUid) return;

  final context = navigatorKey.currentContext;
  if (context == null) return;

  if (contextType == "idleFlag") {
    // Show alert dialog (copied inline here for convenience)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("No Motion Detected"),
        content: Text("Device $deviceId is on and detected no motion for 30 minutes."),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseDatabase.instance
                  .ref("devices/$deviceId/command")
                  .set({"action": "switch_power", "uid": currentUid});
              Navigator.pop(context);
            },
            child: const Text("Turn Off"),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseDatabase.instance
                  .ref("devices/$deviceId/command")
                  .set({"action": "ignore_motion", "uid": currentUid});
              Navigator.pop(context);
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  } else {
    print('📦 TODO: Handle normal notification navigation here');
    // Later you could navigate to RemoteControllerScreen here if needed
  }
}

void showFlutterNotification({
  required String title,
  required String body,
  String? payload,
}) {
  const androidDetails = AndroidNotificationDetails(
    'default_channel',
    'Default',
    channelDescription: 'Default channel for notifications',
    importance: Importance.max,
    priority: Priority.high,
  );

  const notificationDetails = NotificationDetails(android: androidDetails);

  flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    notificationDetails,
    payload: payload,
  );
}