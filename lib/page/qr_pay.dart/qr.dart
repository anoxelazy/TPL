import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrPage extends StatelessWidget {
  const QrPage({super.key});

  String calculateCRC(String payload) {
    int crc = 0xFFFF;
    List<int> bytes = utf8.encode(payload);

    for (int b in bytes) {
      crc ^= (b << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  @override
  Widget build(BuildContext context) {
    String payloadWithoutCRC =
        '00020101021129530016A0000006770101110117660107564000260030202MF0302A15303764540515.595802TH6304';

    String crc = calculateCRC(payloadWithoutCRC);
    String fullPayload = payloadWithoutCRC + crc;

    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Payment"),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: fullPayload,
              version: QrVersions.auto,
              size: 220.0,
            ),
            // const SizedBox(height: 20),
            // Text(
            //   "CRC = $crc",
            //   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            // ),
            // const SizedBox(height: 10),
            // Text(
            //   fullPayload,
            //   textAlign: TextAlign.center,
            //   style: const TextStyle(fontSize: 14),
            // ),
          ],
        ),
      ),
    );
  }
}
