import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart' as qr;

class AcSetupScreen extends StatefulWidget {
  const AcSetupScreen({super.key});

  @override
  _AcSetupScreenState createState() => _AcSetupScreenState();
}

class _AcSetupScreenState extends State<AcSetupScreen> {
  String selectedModel = 'electra';
  int minTemp = 18;
  int maxTemp = 30;
  String ssid = '';
  String password = '';
  bool isCapturing = false;
  bool isSubmitting = false;

  final models = ['electra', 'samsung', 'lg', 'custom'];
  final espUrl = 'http://192.168.4.1'; // ESP32 AP mode IP

  Future<void> captureIR(String type) async {
    setState(() => isCapturing = true);
    final url = Uri.parse('$espUrl/irsetup/$type');
    final response = await http.get(url);
    setState(() => isCapturing = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Captured $type signal')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to capture $type')),
      );
    }
  }

  Future<void> testIR(String type) async {
    final url = Uri.parse('$espUrl/irtest?key=$type');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Tested $type signal')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to test $type signal')),
      );
    }
  }

  Future<void> submitSetup() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ User not logged in')),
      );
      return;
    }

    if (ssid.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please enter Wi-Fi SSID and password')),
      );
      return;
    }

    final body = {
      "model": selectedModel,
      "minTemp": minTemp,
      "maxTemp": maxTemp,
      "ssid": ssid,
      "password": password,
      "uid": user.uid,
    };

    setState(() => isSubmitting = true);
    final response = await http.post(
      Uri.parse('$espUrl/setup'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    setState(() => isSubmitting = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Setup submitted successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Setup failed: ${response.body}')),
      );
    }
  }

  void _showMyQr() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No authenticated user')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Your User UID QR'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('UID: $uid', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                width: 200,
                child: Center(
                  child: qr.QrImageView(
                    data: uid,
                    version: qr.QrVersions.auto,
                    size: 200.0,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget buildCaptureRow(String type, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isCapturing || isSubmitting ? null : () => captureIR(type),
              child: Text(label),
            ),
          ),
          const SizedBox(width: 10),
          ClipOval(
            child: Material(
              color: Colors.blueAccent,
              child: InkWell(
                onTap: isCapturing || isSubmitting ? null : () => testIR(type),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.play_arrow, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModelDropdown() => DropdownButton<String>(
        value: selectedModel,
        items: models
            .map((model) => DropdownMenuItem(value: model, child: Text(model)))
            .toList(),
        onChanged: (value) => setState(() => selectedModel = value!),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AC Initial Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            buildModelDropdown(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Min Temp: $minTemp'),
                Slider(
                  value: minTemp.toDouble(),
                  min: 16,
                  max: 32,
                  divisions: 16,
                  label: minTemp.toString(),
                  onChanged: (value) => setState(() => minTemp = value.toInt()),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Max Temp: $maxTemp'),
                Slider(
                  value: maxTemp.toDouble(),
                  min: 16,
                  max: 32,
                  divisions: 16,
                  label: maxTemp.toString(),
                  onChanged: (value) => setState(() => maxTemp = value.toInt()),
                ),
              ],
            ),
            if (selectedModel == "custom") ...[
              const SizedBox(height: 20),
              buildCaptureRow("on", "Capture ON"),
              buildCaptureRow("off", "Capture OFF"),
              buildCaptureRow("tempUp", "Capture Temp Up"),
              buildCaptureRow("tempDown", "Capture Temp Down"),
            ],
            const SizedBox(height: 20),
            TextFormField(
              decoration: const InputDecoration(labelText: "Wi-Fi SSID"),
              onChanged: (val) => ssid = val,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: "Wi-Fi Password"),
              onChanged: (val) => password = val,
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSubmitting || isCapturing ? null : submitSetup,
              child: isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Submit Setup"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code),
              label: const Text("Show My QR (UID)"),
              onPressed: _showMyQr,
            ),
          ],
        ),
      ),
    );
  }
}