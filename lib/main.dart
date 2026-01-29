import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(home: RdJScannerFinal()));

class RdJScannerFinal extends StatefulWidget {
  const RdJScannerFinal({super.key});
  @override
  State<RdJScannerFinal> createState() => _RdJScannerFinalState();
}

class _RdJScannerFinalState extends State<RdJScannerFinal> {
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? writeChar;
  List<ScanResult> scanResults = [];
  bool isConnecting = false;
  String rpmValue = "0";
  String tempValue = "0";

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  void _checkPermissions() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
  }

  void _startScan() async {
    setState(() => scanResults.clear());
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => scanResults = results);
    });
  }

  // FUNGSI KONEKSI & INISIALISASI PROTOKOL OBD2
  void _connect(BluetoothDevice device) async {
    setState(() => isConnecting = true);
    try {
      await device.connect();
      List<BluetoothService> services = await device.discoverServices();
      
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            writeChar = char;
          }
          if (char.properties.notify) {
            await char.setNotifyValue(true);
            char.lastValueStream.listen(_parseData);
          }
        }
      }

      // PROSES HANDSHAKE ELM327 (PENTING!)
      await _sendCommand("ATZ");    // Reset Modul
      await _sendCommand("ATL0");   // Linefeed Off
      await _sendCommand("ATH0");   // Headers Off
      await _sendCommand("ATSP0");  // Auto Protocol Search
      
      setState(() {
        targetDevice = device;
        isConnecting = false;
      });

      // Mulai Loop Baca Data
      Timer.periodic(const Duration(seconds: 1), (t) {
        if (targetDevice == null) t.cancel();
        _sendCommand("010C"); // Request RPM
      });

    } catch (e) {
      setState(() => isConnecting = false);
      _showSnack("Koneksi Gagal: $e");
    }
  }

  Future<void> _sendCommand(String cmd) async {
    if (writeChar != null) {
      await writeChar!.write(utf8.encode("$cmd\r"));
    }
  }

  void _parseData(List<int> data) {
    String response = utf8.decode(data).trim();
    if (response.contains("41 0C")) { // Response standar untuk RPM
      // Logika konversi Hex ke Decimal (Sederhana)
      setState(() => rpmValue = "Connected"); 
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("RDJ OBD2 SCANNER"), backgroundColor: Colors.orange),
      body: targetDevice == null ? _buildScanner() : _buildDashboard(),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        if (isConnecting) const LinearProgressIndicator(color: Colors.orange),
        Expanded(
          child: ListView.builder(
            itemCount: scanResults.length,
            itemBuilder: (c, i) => ListTile(
              title: Text(scanResults[i].device.platformName.isEmpty ? "OBDII Device" : scanResults[i].device.platformName, style: const TextStyle(color: Colors.white)),
              subtitle: Text(scanResults[i].device.remoteId.toString(), style: const TextStyle(color: Colors.grey)),
              onTap: () => _connect(scanResults[i].device),
            ),
          ),
        ),
        ElevatedButton(onPressed: _startScan, child: const Text("CARI MOTOR")),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDashboard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("STATUS: TERHUBUNG", style: TextStyle(color: Colors.green, fontSize: 18)),
          const SizedBox(height: 30),
          _gauge("ENGINE RPM", rpmValue),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => setState(() => targetDevice = null), 
            child: const Text("PUTUSKAN"),
          )
        ],
      ),
    );
  }

  Widget _gauge(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.orange)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
