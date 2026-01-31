import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(
      home: UltimateScanner(),
      debugShowCheckedModeBanner: false,
    ));

class UltimateScanner extends StatefulWidget {
  const UltimateScanner({super.key});
  @override
  State<UltimateScanner> createState() => _UltimateScannerState();
}

class _UltimateScannerState extends State<UltimateScanner> {
  // --- STATE SENSOR ---
  int rpm = 0; int temp = 0; double tps = 0.0; double volt = 0.0;
  double map = 0.0; double o2 = 0.0; double inj = 0.0;
  
  String connectionStatus = "SIAP SCANNING";
  String dtcStatus = "STB";
  String selectedBrand = "HONDA"; 
  bool isConnected = false;
  BluetoothCharacteristic? targetChar;

  // --- 1. KONEKSI & DISCOVERY ---
  void _initScan() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    setState(() => connectionStatus = "MENCARI PERANGKAT...");
    
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        String name = r.device.platformName.toUpperCase();
        if (name.contains("OBD") || name.contains("ELM")) {
          FlutterBluePlus.stopScan();
          _connectDevice(r.device);
          break;
        }
      }
    });
  }

  void _connectDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);
      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write) {
            targetChar = c;
            _setupECU();
            return;
          }
        }
      }
    } catch (e) { setState(() => connectionStatus = "GAGAL KONEK"); }
  }

  // --- 2. PENYESUAIAN ECU & PROTOKOL ---
  void _setupECU() async {
    setState(() => connectionStatus = "KONFIGURASI ECU...");
    _listenData();
    
    await _send("ATZ\r"); 
    await Future.delayed(const Duration(milliseconds: 1000));
    await _send("ATE0\r"); 
    await Future.delayed(const Duration(milliseconds: 400));
    await _send("ATSP5\r"); 
    await Future.delayed(const Duration(milliseconds: 400));

    if (selectedBrand == "HONDA") {
      await _send("ATSH8111F1\r"); 
    } else {
      await _send("ATSH\r"); 
    }
    
    setState(() { isConnected = true; connectionStatus = "ONLINE ($selectedBrand)"; });
    _startLiveQuery();
  }

  // --- 3. LIVE QUERY ---
  void _startLiveQuery() {
    Timer.periodic(const Duration(milliseconds: 300), (t) async {
      if (!isConnected || targetChar == null) return;
      int step = t.tick % 8;
      switch (step) {
        case 0: await _send("010C\r"); break;
        case 1: await _send("0111\r"); break;
        case 2: await _send("0105\r"); break;
        case 3: await _send("010B\r"); break;
        case 4: await _send("0114\r"); break;
        case 5: await _send("015E\r"); break;
        case 6: await _send("0142\r"); break;
        case 7: await _send("03\r");   break;
      }
    });
  }

  // --- 4. SMART PARSING ---
  void _listenData() async {
    await targetChar!.setNotifyValue(true);
    targetChar!.lastValueStream.listen((data) {
      if (data.isEmpty) return;
      String hex = utf8.decode(data).toUpperCase().replaceAll(" ", "");
      try {
        if (hex.contains("410C")) {
          int i = hex.indexOf("410C") + 4;
          int a = int.parse(hex.substring(i, i+2), radix: 16);
          int b = int.parse(hex.substring(i+2, i+4), radix: 16);
          setState(() => rpm = ((a * 256) + b) ~/ 4);
        } else if (hex.contains("4111")) {
          int i = hex.indexOf("4111") + 4;
          int a = int.parse(hex.substring(i, i+2), radix: 16);
          setState(() => tps = (a * 100) / 255);
        } else if (hex.contains("4105")) {
          int i = hex.indexOf("4105") + 4;
          int a = int.parse(hex.substring(i, i+2), radix: 16);
          setState(() => temp = a - 40);
        } else if (hex.contains("410B")) {
          int i = hex.indexOf("410B") + 4;
          int a = int.parse(hex.substring(i, i+2), radix: 16);
          setState(() => map = a.toDouble());
        } else if (hex.contains("4114")) {
          int i = hex.indexOf("4114") + 4;
          int a = int.parse(hex.substring(i, i+2), radix: 16);
          setState(() => o2 = a / 200);
        } else if (hex.contains("415E")) {
          int i = hex.indexOf("415E") + 4;
          int a = int.parse(hex.substring(i, i+2), radix: 16);
          int b = int.parse(hex.substring(i+2, i+4), radix: 16);
          setState(() => inj = ((a * 256) + b) / 3215);
        } else if (hex.contains("4142")) {
          int i = hex.indexOf("4142") + 4;
          int a = int.parse(hex.substring(i, i+2), radix: 16);
          int b = int.parse(hex.substring(i+2, i+4), radix: 16);
          setState(() => volt = ((a * 256) + b) / 1000);
        } else if (hex.contains("43")) {
          setState(() => dtcStatus = hex.contains("4300") ? "NORMAL" : "ERROR!");
        }
      } catch (e) { /* Error parsing */ }
    });
  }

  Future<void> _send(String cmd) async => await targetChar?.write(utf8.encode(cmd), withoutResponse: true);

  // --- 5. UI COMPONENTS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("RDJ ULTIMATE SCANNER", style: TextStyle(fontSize: 14)),
        backgroundColor: Colors.black,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _initScan)],
      ),
      body: Column(
        children: [
          _brandSelector(),
          _heroRPM(),
          Expanded(child: _gridSensors()),
          _footerDTC(),
        ],
      ),
    );
  }

  Widget _brandSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _btnBrand("HONDA", Colors.red),
        const SizedBox(width: 15),
        _btnBrand("YAMAHA", Colors.blue),
      ]),
    );
  }

  Widget _btnBrand(String b, Color c) {
    bool active = selectedBrand == b;
    return GestureDetector(
      onTap: () => setState(() => selectedBrand = b),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
        decoration: BoxDecoration(color: active ? c : Colors.white10, borderRadius: BorderRadius.circular(15)),
        child: Text(b, style: TextStyle(color: active ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _heroRPM() {
    return SizedBox(
      height: 160,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(connectionStatus, style: TextStyle(color: isConnected ? Colors.green : Colors.red, fontSize: 10)),
        Text("$rpm", style: const TextStyle(fontSize: 80, color: Colors.white, fontWeight: FontWeight.bold)),
        const Text("RPM", style: TextStyle(color: Colors.white24, letterSpacing: 4)),
      ]),
    );
  }

  Widget _gridSensors() {
    return GridView.count(
      crossAxisCount: 2, padding: const EdgeInsets.symmetric(horizontal: 15),
      childAspectRatio: 1.6, crossAxisSpacing: 10, mainAxisSpacing: 10,
      children: [
        _tile("GAS (TPS)", "${tps.toStringAsFixed(1)} %", Colors.blue),
        _tile("SUHU", "$temp °C", Colors.orange),
        _tile("TEKANAN MAP", "${map.toStringAsFixed(0)} kPa", Colors.purple),
        _tile("O2 SENSOR", "${o2.toStringAsFixed(2)} V", Colors.green),
        _tile("INJEKTOR", "${inj.toStringAsFixed(2)} ms", Colors.cyan),
        _tile("AKI", "${volt.toStringAsFixed(1)} V", Colors.yellow),
      ],
    );
  }

  Widget _tile(String t, String v, Color c) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(t, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        Text(v, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _footerDTC() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("DTC STATUS", style: TextStyle(color: Colors.white38, fontSize: 10)),
            Text(dtcStatus, style: TextStyle(color: dtcStatus == "NORMAL" ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
          ]),
          Row(children: [
            ElevatedButton(onPressed: () => _send("04\r"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]), child: const Text("HAPUS")),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _setupECU, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]), child: const Text("RE-INIT")),
          ]),
        ],
      ),
    );
  }
}
