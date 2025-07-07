import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  bool _hasScanned = false;

  void _handleDetection(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.first;
    final String? value = barcode.rawValue;
    if (value != null && mounted) {
      _hasScanned = true;
      controller.stop(); // 👈 stop camera before popping
      Navigator.pop(context, value);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan User UID')),
      body: MobileScanner(
        controller: controller,
        onDetect: _handleDetection,
      ),
    );
  }
}