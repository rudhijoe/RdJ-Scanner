import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(home: RdJScannerFinal(), debugShowCheckedModeBanner: false));

class RdJScannerFinal extends StatefulWidget {
  const RdJScannerFinal({super.key});
  @override
  State<RdJScannerFinal> createState() => _RdJScannerFinalState();
}

class _RdJScannerFinalState extends State<RdJScannerFinal> {
  // SENSOR DATA
  int rpm = 0; double volt = 0.0; int eot = 0;
  double tps = 0.0; int map = 0; double inj = 0.0; double afr = 0.0;

  BluetoothCharacteristic? targetChar;
  String connectionStatus = "Mencari ELM327...";
  String rawLog = "Log: Menunggu koneksi...";
  bool isConnected = false;
  bool isProtocolFound = false;

  // SEMUA PROTOKOL OBD2 (0-9)
  final List<String> allProtocols = ["ATSP6", "ATSP5", "ATSP2", "ATSP4", "ATSP7", "ATSP3", "ATSP1", "ATSP0"];

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
        if (r.device.platformName.toUpperCase().contains("OBD") || r.device.platformName.toUpperCase().contains("ELM")) {
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
            setState(() { isConnected = true; connectionStatus = "HANDSHAKE..."; });
            _startListening();
            _forceProtocolDiscovery();
            return;
          }
        }
      }
    } catch (e) { setState(() => connectionStatus = "KONEKSI GAGAL"); }
  }

  // LOGIKA "BRUTE FORCE" PROTOKOL
  void _forceProtocolDiscovery() async {
    await _sendCommand("ATZ\r"); // Reset
    await Future.delayed(const Duration(seconds: 1));
    await _sendCommand("ATE0\r"); // Echo Off (Wajib agar respon bersih)
    await Future.delayed(const Duration(milliseconds: 300));

    for (String proto in allProtocols) {
      if (isProtocolFound) break;
      setState(() {
        connectionStatus = "MENCOBA $proto...";
        rawLog = "Init: Mengirim $proto";
      });

      await _sendCommand("$proto\r");
      await Future.delayed(const Duration(milliseconds: 500));

      // Jika protokol KWP (Honda Lama/Vario), kirim Header
      if (proto == "ATSP5" || proto == "ATSP2" || proto == "ATSP4") {
        await _sendCommand("ATSH8111F1\r"); 
        await Future.delayed(const Duration(milliseconds: 300));
      }

      await _sendCommand("010C\r"); // Test RPM
      await Future.delayed(const Duration(seconds: 2));

      if (rpm > 0) {
        isProtocolFound = true;
        setState(() => connectionStatus = "BERHASIL ($proto)");
        _startQueryLoop();
        return;
      }
    }
    if (!isProtocolFound) setState(() => connectionStatus = "ECU TIDAK NYAMBUNG");
  }

  void _startQueryLoop() {
    Timer.periodic(const Duration(milliseconds: 500), (t) async {
      if (!isConnected || !isProtocolFound) return;
      await _sendCommand("010C\r"); // RPM
      await Future.delayed(const Duration(milliseconds: 100));
      await _sendCommand("0105\r"); // EOT
    });
  }

  Future<void> _sendCommand(String cmd) async {
    if (targetChar != null) {
      await targetChar!.write(utf8.encode(cmd), withoutResponse: true);
    }
  }

  void _startListening() async {
    await targetChar!.setNotifyValue(true);
    targetChar!.lastValueStream.listen((data) {
      if (data.isEmpty) return;
      String res = utf8.decode(data).trim().toUpperCase();
      setState(() => rawLog = "Respon: $res"); // Update log di layar

      if (res.contains("410C") || res.contains("41 0C")) {
        String cleanRes = res.replaceAll(" ", "");
        try {
          int idx = cleanRes.indexOf("410C");
          String valHex = cleanRes.substring(idx + 4, idx + 8);
          int a = int.parse(valHex.substring(0, 2), radix: 16);
          int b = int.parse(valHex.substring(2, 4), radix: 16);
          setState(() { rpm = ((a * 256) + b) ~/ 4; isProtocolFound = true; });
        } catch (e) {}
      }
    });
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(connectionStatus, style: const TextStyle(fontSize: 14)),
        backgroundColor: isProtocolFound ? Colors.green[900] : Colors.red[900],
      ),
      body: Column(
        children: [
          _buildBigDisplay("RPM", "$rpm", "ENGINE SPEED"),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2, childAspectRatio: 1.6,
              children: [
                _sensorBox("SUHU (EOT)", "$eot", "°C", Colors.orange),
                _sensorBox("BUKAAN GAS", "$tps", "%", Colors.blue),
                _sensorBox("VOLT AKI", "$volt", "V", Colors.green),
                _sensorBox("AFR", "$afr", ":1", Colors.yellow),
              ],
            ),
          ),
          // MONITORING RAW LOG (Sangat berguna untuk debug)
          Container(
            width: double.infinity, height: 60, color: Colors.blueGrey[900],
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(child: Text(rawLog, style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'))),
          ),
          _actionPanel(),
        ],
      ),
    );
  }

  Widget _buildBigDisplay(String l, String v, String d) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(children: [
        Text(l, style: const TextStyle(color: Colors.white54)),
        Text(v, style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(d, style: const TextStyle(color: Colors.red, fontSize: 10)),
      ]),
    );
  }

  Widget _sensorBox(String l, String v, String u, Color c) {
    return Card(color: Colors.white10, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(l, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      Text(v, style: TextStyle(fontSize: 22, color: c, fontWeight: FontWeight.bold)),
      Text(u, style: const TextStyle(fontSize: 10)),
    ]));
  }

  Widget _actionPanel() {
    return Container(
      padding: const EdgeInsets.all(10), color: Colors.grey[900],
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _btn("RISET ECU", () => _sendCommand("ATZ\r"), Colors.blue),
        _btn("HAPUS DTC", () => _sendCommand("04\r"), Colors.red),
      ]),
    );
  }

  Widget _btn(String t, VoidCallback f, Color c) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: c.withOpacity(0.2)), onPressed: f, child: Text(t, style: const TextStyle(fontSize: 10)));
}
