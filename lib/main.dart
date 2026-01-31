import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(
      home: RdJScannerFinal(),
      debugShowCheckedModeBanner: false,
    ));

class RdJScannerFinal extends StatefulWidget {
  const RdJScannerFinal({super.key});
  @override
  State<RdJScannerFinal> createState() => _RdJScannerFinalState();
}

class _RdJScannerFinalState extends State<RdJScannerFinal> {
  // 7 SENSOR POKOK
  int rpm = 0; double volt = 0.0; int eot = 0;
  double tps = 0.0; int map = 0; double inj = 0.0; double afr = 14.7;

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetChar;
  String connectionStatus = "Mencari ELM327...";
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  void _initScanner() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        // Penyesuaian: Menggunakan platformName atau remoteId
        if (r.device.platformName.contains("OBD") || r.device.platformName.contains("ELM")) {
          FlutterBluePlus.stopScan();
          _connectToDevice(r.device);
          break;
        }
      }
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write || c.properties.notify) {
            targetChar = c;
            setState(() {
              isConnected = true;
              connectionStatus = "TERHUBUNG KE MOTOR";
            });
            _startListening();
            _startQueryLoop();
          }
        }
      }
    } catch (e) {
      setState(() => connectionStatus = "KONEKSI GAGAL");
    }
  }

  void _startQueryLoop() {
    Timer.periodic(const Duration(milliseconds: 350), (t) async {
      if (!isConnected || targetChar == null) return;
      await _sendCommand("010C\r"); // RPM
      await Future.delayed(const Duration(milliseconds: 60));
      await _sendCommand("0105\r"); // EOT
      await Future.delayed(const Duration(milliseconds: 60));
      await _sendCommand("0111\r"); // TPS
    });
  }

  // PERBAIKAN: Parameter 'obedience' dihapus untuk versi Flutter Blue Plus terbaru
  Future<void> _sendCommand(String cmd) async {
    if (targetChar != null) {
      await targetChar!.write(utf8.encode(cmd), withoutResponse: true);
    }
  }

  void _startListening() async {
    await targetChar!.setNotifyValue(true);
    targetChar!.lastValueStream.listen((data) {
      if (data.isEmpty) return;
      String response = utf8.decode(data).trim();
      
      if (response.contains("41 0C")) {
        List<String> p = response.split(" ");
        if (p.length >= 4) {
          int a = int.parse(p[2], radix: 16);
          int b = int.parse(p[3], radix: 16);
          setState(() => rpm = ((a * 256) + b) ~/ 4);
        }
      } else if (response.contains("41 05")) {
        int a = int.parse(response.split(" ")[2], radix: 16);
        setState(() => eot = a - 40);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(connectionStatus, style: const TextStyle(fontSize: 12)),
        backgroundColor: isConnected ? Colors.green[900] : Colors.red[900],
      ),
      body: Column(
        children: [
          _buildBigDisplay("RPM", "$rpm", "ENGINE SPEED"),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(10),
              childAspectRatio: 1.4,
              children: [
                _sensorBox("SUHU (EOT)", "$eot", "°C", Colors.orange),
                _sensorBox("BUKAAN GAS", "$tps", "%", Colors.blue),
                _sensorBox("VOLT AKI", "$volt", "V", Colors.green),
                _sensorBox("TEKANAN MAP", "$map", "kPa", Colors.purple),
                _sensorBox("INJEKSI", "$inj", "ms", Colors.cyan),
                _sensorBox("RASIO AFR", "$afr", ":1", Colors.yellow),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionBtn("RISET TPS", () => _sendCommand("AT RESET TPS\r"), Colors.orange),
                _actionBtn("RISET ECU", () => _sendCommand("ATZ\r"), Colors.blue),
                _actionBtn("HAPUS DTC", () => _sendCommand("04\r"), Colors.red),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBigDisplay(String label, String value, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      color: Colors.red[900]!.withOpacity(0.1),
      child: Column(children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        Text(value, style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold)),
        Text(desc, style: const TextStyle(color: Colors.red, fontSize: 10)),
      ]),
    );
  }

  Widget _sensorBox(String l, String v, String u, Color c) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        Text(v, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c)),
        Text(u, style: const TextStyle(fontSize: 10)),
      ]),
    );
  }

  Widget _actionBtn(String txt, VoidCallback tap, Color c) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: c.withOpacity(0.2), side: BorderSide(color: c)),
      onPressed: tap,
      child: Text(txt, style: const TextStyle(fontSize: 10, color: Colors.white)),
    );
  }
}
