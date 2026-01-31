import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(home: YamahaDiagExpert(), debugShowCheckedModeBanner: false));

class YamahaDiagExpert extends StatefulWidget {
  const YamahaDiagExpert({super.key});
  @override
  State<YamahaDiagExpert> createState() => _YamahaDiagExpertState();
}

class _YamahaDiagExpertState extends State<YamahaDiagExpert> {
  // DATA SENSOR
  int rpm = 0; int temp = 0; double tps = 0.0; double volt = 0.0;
  String dtcStatus = "SISTEM NORMAL";
  String connectionStatus = "MENCARI YAMAHA...";
  bool isConnected = false;
  BluetoothCharacteristic? targetChar;

  // DATABASE DTC YAMAHA (Format P-Code)
  final Map<String, String> yamahaDTC = {
    "P0335": "12: Sensor Crankshaft (CKP) Bermasalah",
    "P0105": "13: Sensor Tekanan Udara (MAP) Bermasalah",
    "P0110": "14: Sensor Suhu Udara (IAT) Bermasalah",
    "P0115": "15: Sensor Suhu Mesin (Coolant/EOT) Bermasalah",
    "P0120": "21: Sensor Posisi Gas (TPS) Bermasalah",
    "P0500": "42: Sensor Kecepatan Roda Depan Bermasalah",
  };

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  // 1. KONEKSI STABIL YAMAHA
  void _startScan() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName.toUpperCase().contains("OBD") || r.device.platformName.toUpperCase().contains("ELM")) {
          FlutterBluePlus.stopScan();
          _connectToYamaha(r.device);
          break;
        }
      }
    });
  }

  void _connectToYamaha(BluetoothDevice device) async {
    await device.connect(autoConnect: false);
    List<BluetoothService> services = await device.discoverServices();
    for (var s in services) {
      for (var c in s.characteristics) {
        if (c.properties.write) {
          targetChar = c;
          setState(() { isConnected = true; connectionStatus = "HANDSHAKE YAMAHA..."; });
          _listenToYamaha();
          _initYamahaProtocol();
          return;
        }
      }
    }
  }

  // 2. YAMAHA K-LINE INITIALIZATION
  void _initYamahaProtocol() async {
    await Future.delayed(const Duration(seconds: 1));
    await _send("ATZ\r");       // Reset
    await Future.delayed(const Duration(milliseconds: 800));
    await _send("ATE0\r");      // Echo Off
    await Future.delayed(const Duration(milliseconds: 400));
    await _send("ATSP5\r");     // Protokol KWP (Yamaha Indonesia)
    await Future.delayed(const Duration(milliseconds: 400));
    await _send("ATSH\r");      // Reset Header ke Default (Yamaha tdk pakai Header Honda)
    
    _runQueryLoop();
  }

  // 3. POLLING DATA (Real-Time)
  void _runQueryLoop() {
    Timer.periodic(const Duration(milliseconds: 400), (t) async {
      if (!isConnected) return;
      // Yamaha lebih stabil jika data diminta satu per satu
      if (t.tick % 5 == 0) {
        await _send("03\r"); // Cek DTC setiap 2 detik
      } else {
        await _send("010C\r"); // Minta RPM
        await Future.delayed(const Duration(milliseconds: 100));
        await _send("0105\r"); // Minta Suhu Mesin
      }
    });
  }

  // 4. PARSING YAMAHA DATA
  void _listenToYamaha() async {
    await targetChar!.setNotifyValue(true);
    targetChar!.lastValueStream.listen((data) {
      String hex = utf8.decode(data).toUpperCase().replaceAll(" ", "");
      
      if (hex.contains("410C")) { // RPM Logic
        try {
          int i = hex.indexOf("410C") + 4;
          int a = int.parse(hex.substring(i, i+2), radix: 16);
          int b = int.parse(hex.substring(i+2, i+4), radix: 16);
          setState(() { rpm = ((a * 256) + b) ~/ 4; connectionStatus = "YAMAHA CONNECTED"; });
        } catch (e) {}
      } 
      else if (hex.contains("4105")) { // Temp Logic
        try {
          int i = hex.indexOf("4105") + 4;
          int a = int.parse(hex.substring(i, i+2), radix: 16);
          setState(() => temp = a - 40);
        } catch (e) {}
      }
      else if (hex.contains("43")) { // DTC Logic (Yamaha P-Codes)
        try {
          String code = "P" + hex.substring(hex.indexOf("43") + 2, hex.indexOf("43") + 6);
          setState(() => dtcStatus = yamahaDTC[code] ?? "ERROR: $code");
        } catch (e) {}
      }
    });
  }

  Future<void> _send(String cmd) async => await targetChar?.write(utf8.encode(cmd), withoutResponse: true);

  // --- UI DESIGN YAMAHA BLUE CORE ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F), // Yamaha Deep Blue
      appBar: AppBar(title: const Text("YAMAHA DIAGNOSTIC TOOL"), backgroundColor: const Color(0xFF0044CC)),
      body: Column(
        children: [
          _statusBanner(),
          _rpmDisplay(),
          _dtcBox(),
          _sensorGrid(),
          _footerActions(),
        ],
      ),
    );
  }

  Widget _statusBanner() => Container(width: double.infinity, color: Colors.blueAccent, padding: const EdgeInsets.all(5), child: Text(connectionStatus, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)));

  Widget _rpmDisplay() => Container(padding: const EdgeInsets.symmetric(vertical: 40), child: Column(children: [
    const Text("ENGINE SPEED", style: TextStyle(color: Colors.blueAccent)),
    Text("$rpm", style: const TextStyle(fontSize: 100, fontWeight: FontWeight.bold, color: Colors.white)),
    const Text("RPM", style: TextStyle(color: Colors.white54)),
  ]));

  Widget _dtcBox() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 15), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: dtcStatus == "SISTEM NORMAL" ? Colors.green[900] : Colors.red[900], borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: Colors.white),
      const SizedBox(width: 15),
      Expanded(child: Text(dtcStatus, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    ]),
  );

  Widget _sensorGrid() => Expanded(child: GridView.count(crossAxisCount: 2, padding: const EdgeInsets.all(10), children: [
    _tile("COOLANT TEMP", "$temp °C"),
    _tile("BATTERY", "14.2 V"),
  ]));

  Widget _tile(String t, String v) => Card(color: Colors.white10, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    Text(v, style: const TextStyle(color: Colors.blueAccent, fontSize: 24, fontWeight: FontWeight.bold)),
  ]));

  Widget _footerActions() => Container(padding: const EdgeInsets.all(20), color: Colors.black26, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => _send("04\r"), child: const Text("RESET DTC")),
    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), onPressed: () => _send("ATZ\r"), child: const Text("RESET MODULE")),
  ]));
}
