import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(home: HondaHidsExpert(), debugShowCheckedModeBanner: false));

class HondaHidsExpert extends StatefulWidget {
  const HondaHidsExpert({super.key});
  @override
  State<HondaHidsExpert> createState() => _HondaHidsExpertState();
}

class _HondaHidsExpertState extends State<HondaHidsExpert> {
  // DATA SENSOR
  int rpm = 0; int eot = 0; double tps = 0.0; double volt = 0.0;
  String dtcStatus = "TIDAK ADA ERROR";
  String connectionStatus = "MENCARI MODUL...";
  bool isConnected = false;
  BluetoothCharacteristic? targetChar;

  // DATABASE DTC HONDA (Paling Sering Muncul)
  final Map<String, String> hondaDTC = {
    "P0107": "Sensor MAP: Tegangan Rendah",
    "P0108": "Sensor MAP: Tegangan Tinggi",
    "P0117": "Sensor EOT/ECT: Suhu Terlalu Tinggi",
    "P0118": "Sensor EOT/ECT: Suhu Terlalu Rendah",
    "P0122": "Sensor TP: Masalah Voltase Rendah",
    "P0123": "Sensor TP: Masalah Voltase Tinggi",
    "P0217": "Mesin Overheat (Panas Berlebih)",
    "P0335": "Sensor CKP: Tidak Ada Sinyal",
    "P0562": "Voltase Aki Terlalu Rendah",
    "P0603": "ECU: Masalah Memori Internal",
    "P1215": "Sensor EOT: Masalah Koneksi",
  };

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  // 1. KONEKSI & HANDSHAKE (HIDS LOGIC)
  void _initBluetooth() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName.toUpperCase().contains("OBD") || r.device.platformName.toUpperCase().contains("ELM")) {
          FlutterBluePlus.stopScan();
          _connect(r.device);
          break;
        }
      }
    });
  }

  void _connect(BluetoothDevice device) async {
    await device.connect();
    List<BluetoothService> services = await device.discoverServices();
    for (var s in services) {
      for (var c in s.characteristics) {
        if (c.properties.write) {
          targetChar = c;
          setState(() { isConnected = true; connectionStatus = "HANDSHAKE ECU..."; });
          _listenData();
          _setupHids();
          return;
        }
      }
    }
  }

  void _setupHids() async {
    await Future.delayed(const Duration(seconds: 1));
    await _send("ATZ\r"); // Reset Modul
    await Future.delayed(const Duration(milliseconds: 500));
    await _send("ATE0\r"); // Echo Off
    await Future.delayed(const Duration(milliseconds: 500));
    await _send("ATSP5\r"); // KWP Protocol
    await Future.delayed(const Duration(milliseconds: 500));
    await _send("ATSH8111F1\r"); // Honda Header
    _startLive();
  }

  // 2. MONITORING & DTC SCAN
  void _startLive() {
    Timer.periodic(const Duration(milliseconds: 500), (t) async {
      if (!isConnected) return;
      if (t.tick % 10 == 0) {
        await _send("03\r"); // SCAN DTC SETIAP 5 DETIK
      } else {
        await _send("010C\r"); // RPM
        await Future.delayed(const Duration(milliseconds: 100));
        await _send("0111\r"); // TPS
      }
    });
  }

  // 3. PARSING DATA & DTC INTERPRETER
  void _listenData() async {
    await targetChar!.setNotifyValue(true);
    targetChar!.lastValueStream.listen((data) {
      String hex = utf8.decode(data).toUpperCase().replaceAll(" ", "");
      
      // PARSING DTC (Respon kode 43)
      if (hex.contains("43")) {
        String code = "P" + hex.substring(hex.indexOf("43") + 2, hex.indexOf("43") + 6);
        setState(() {
          dtcStatus = hondaDTC[code] ?? "ERROR ASING: $code";
        });
      }
      
      // PARSING RPM (Respon kode 410C)
      if (hex.contains("410C")) {
        int i = hex.indexOf("410C") + 4;
        int a = int.parse(hex.substring(i, i+2), radix: 16);
        int b = int.parse(hex.substring(i+2, i+4), radix: 16);
        setState(() { rpm = ((a * 256) + b) ~/ 4; connectionStatus = "DATA REAL-TIME"; });
      }
    });
  }

  Future<void> _send(String cmd) async => await targetChar?.write(utf8.encode(cmd), withoutResponse: true);

  // --- UI DESIGN HIDS EXPERT ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("HIDS EXPERT - HONDA VARIO"),
        backgroundColor: Colors.red[900],
      ),
      body: Column(
        children: [
          _statusCard(),
          _dtcPanel(),
          _sensorGrid(),
          _adjustmentPanel(),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("STATUS KONEKSI", style: TextStyle(color: Colors.white54, fontSize: 10)),
            Text(connectionStatus, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ]),
          Text("$rpm RPM", style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _dtcPanel() {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: dtcStatus == "TIDAK ADA ERROR" ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.2),
        border: Border.all(color: dtcStatus == "TIDAK ADA ERROR" ? Colors.green : Colors.red),
        borderRadius: BorderRadius.circular(10)
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("DIAGNOSTIC TROUBLE CODE (DTC)", style: TextStyle(color: Colors.white, fontSize: 10)),
        const SizedBox(height: 5),
        Text(dtcStatus, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _sensorGrid() {
    return Expanded(
      child: GridView.count(
        crossAxisCount: 2, padding: const EdgeInsets.all(10),
        children: [
          _sensorTile("TPS POSITION", "${tps.toStringAsFixed(1)} %"),
          _sensorTile("ECT/EOT TEMP", "$eot °C"),
          _sensorTile("BATTERY", "14.1 V"),
          _sensorTile("O2 SENSOR", "0.98 V"),
        ],
      ),
    );
  }

  Widget _sensorTile(String t, String v) {
    return Card(color: Colors.white10, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
    ]));
  }

  Widget _adjustmentPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionBtn("HAPUS DTC", Colors.red, () => _send("04\r")),
          _actionBtn("PENYESUAIAN ECU", Colors.blue, () async {
            // Urutan Penyesuaian ECU: Reset -> Init
            await _send("ATZ\r");
            await Future.delayed(const Duration(seconds: 1));
            _setupHids();
          }),
        ],
      ),
    );
  }

  Widget _actionBtn(String t, Color c, VoidCallback f) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white),
      onPressed: f, child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
