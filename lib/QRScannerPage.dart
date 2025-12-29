import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  String? qrText;
  Map<String, dynamic>? qrDetails;
  bool isScanned = false; // prevent multiple pops

  void _handleScan(String rawValue) {
    setState(() {
      qrText = rawValue;
      // Try to parse as JSON first
      try {
        final parsed = jsonDecode(rawValue);
        if (parsed is Map<String, dynamic>) {
          if (parsed.containsKey('result')) {
            final resultValue = parsed['result'];
            if (resultValue is String) {
              qrDetails = _parseMapString(resultValue);
            } else if (resultValue is Map<String, dynamic>) {
              qrDetails = resultValue;
            } else {
              qrDetails = parsed;
            }
          } else {
            qrDetails = parsed;
          }
        } else {
          qrDetails = null;
        }
      } catch (_) {
        // Not valid JSON, try to parse as "result:{id:1,...}"
        if (rawValue.startsWith('result:')) {
          final mapStr = rawValue.substring(7).trim();
          qrDetails = _parseMapString(mapStr);
        } else {
          qrDetails = null;
        }
      }
    });
    isScanned = true;
    // Optionally: Don't pop immediately, let user see details
    // Navigator.pop(context, rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    if (!isScanned) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final String? rawValue = barcode.rawValue;
                        if (rawValue != null) {
                          _handleScan(rawValue);
                          Navigator.pop(context, rawValue);
                          break;
                        }
                      }
                    }
                  },
                ),
                // AR border overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 4),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: CustomPaint(
                      painter: _QrBorderPainter(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: qrText == null
                  ? const Text('Scan a code', style: TextStyle(fontSize: 16))
                  : const Text('Scan complete!', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _parseMapString(String mapStr) {
    final cleaned = mapStr.replaceAll(RegExp(r'^{|}$'), '');
    final entries = cleaned.split(',').map((e) => e.split(':')).where((e) => e.length == 2);
    return {for (var pair in entries) pair[0].trim(): pair[1].trim()};
  }
}

class _QrBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Draw corners for AR effect
    double cornerLength = 32;
    // Top left
    canvas.drawLine(Offset(0, 0), Offset(cornerLength, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(0, cornerLength), paint);
    // Top right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);
    // Bottom left
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    // Bottom right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}