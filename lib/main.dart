
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
  // --- STATE SENSOR ---
  int rpm = 0; double volt = 0.0; int eot = 0;
  double tps = 0.0; int map = 0; double inj = 0.0; double afr = 0.0;

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetChar;
  String connectionStatus = "Mencari ELM327...";
  bool isConnected = false;
  bool isProtocolFound = false;

  // --- DAFTAR PROTOKOL UNTUK AUTO-DETECT ---
  // ATSP6: CAN Bus (Vario Baru/PCX), ATSP5: KWP (Vario Lama), ATSP0: Auto
  final List<String> protocols = ["ATSP6", "ATSP5", "ATSP2", "ATSP0"];
  int currentProtocolIndex = 0;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  // 1. SCANNING
  void _initScanner() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName.toUpperCase().contains("OBD") || 
            r.device.platformName.toUpperCase().contains("ELM")) {
          FlutterBluePlus.stopScan();
          _connectToDevice(r.device);
          break;
        }
      }
    });
  }

  // 2. KONEKSI & SEARCH CHARACTERISTIC
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
              connectionStatus = "MEMULAI HANDSHAKE...";
            });
            _startListening();
            _runSmartProtocolInit(); // Memulai proses Auto-Protocol
            return;
          }
        }
      }
    } catch (e) {
      setState(() => connectionStatus = "KONEKSI GAGAL");
    }
  }

  // 3. LOGIKA AUTO-PROTOCOL (Mencari Bahasa ECU)
  void _runSmartProtocolInit() async {
    for (String proto in protocols) {
      if (isProtocolFound) break;

      setState(() => connectionStatus = "MENCOBA PROTOKOL: $proto");
      
      await _sendCommand("ATZ\r"); // Reset
      await Future.delayed(const Duration(milliseconds: 600));
      await _sendCommand("$proto\r"); // Set Protokol
      await Future.delayed(const Duration(milliseconds: 300));
      await _sendCommand("010C\r"); // Tanya RPM sebagai umpan
      
      // Tunggu 2 detik untuk melihat apakah ada balasan RPM
      await Future.delayed(const Duration(seconds: 2));
      
      if (rpm > 0) {
        isProtocolFound = true;
        setState(() => connectionStatus = "TERHUBUNG ($proto)");
        _startQueryLoop();
        return;
      }
    }

    if (!isProtocolFound) {
      setState(() => connectionStatus = "PROTOKOL TIDAK COCOK");
    }
  }

  // 4. DATA QUERY LOOP (Berjalan jika protokol ketemu)
  void _startQueryLoop() {
    Timer.periodic(const Duration(milliseconds: 400), (t) async {
      if (!isConnected || !isProtocolFound) return;
      
      await _sendCommand("010C\r"); // RPM
      await Future.delayed(const Duration(milliseconds: 80));
      await _sendCommand("0105\r"); // EOT
      await Future.delayed(const Duration(milliseconds: 80));
      await _sendCommand("0111\r"); // TPS
    });
  }

  Future<void> _sendCommand(String cmd) async {
    if (targetChar != null) {
      await targetChar!.write(utf8.encode(cmd), withoutResponse: true);
    }
  }

  // 5. PARSING DATA (HEX TO DECIMAL)
  void _startListening() async {
    await targetChar!.setNotifyValue(true);
    targetChar!.lastValueStream.listen((data) {
      if (data.isEmpty) return;
      String res = utf8.decode(data).trim().replaceAll(" ", "");
      
      // Filter Respon RPM (410C)
      if (res.contains("410C")) {
        try {
          String valHex = res.substring(res.indexOf("410C") + 4, res.indexOf("410C") + 8);
          int a = int.parse(valHex.substring(0, 2), radix: 16);
          int b = int.parse(valHex.substring(2, 4), radix: 16);
          setState(() {
            rpm = ((a * 256) + b) ~/ 4;
            isProtocolFound = true; // Konfirmasi protokol berhasil
          });
        } catch (e) {}
      } 
      // Filter Respon EOT (4105)
      else if (res.contains("4105")) {
        try {
          String valHex = res.substring(res.indexOf("4105") + 4, res.indexOf("4105") + 6);
          int a = int.parse(valHex, radix: 16);
          setState(() => eot = a - 40);
        } catch (e) {}
      }
    });
  }

  // --- UI RENDERING ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(connectionStatus, style: const TextStyle(fontSize: 12, color: Colors.white)),
        backgroundColor: isProtocolFound ? Colors.green[900] : Colors.red[900],
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildBigDisplay("RPM", "$rpm", "ENGINE SPEED (LIVE)"),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(10),
              childAspectRatio: 1.5,
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
                _actionBtn("RISET TPS", () => _sendCommand("0100\r"), Colors.orange),
                _actionBtn("RISET ECU", () => _sendCommand("ATZ\r"), Colors.blue),
                _actionBtn("HAPUS DTC", () => _sendCommand("04\r"), Colors.red),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- UI WIDGETS ---
  Widget _buildBigDisplay(String label, String value, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 25),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.red[900]!, width: 0.5))),
      child: Column(children: [
        Text(label, style: const TextStyle(color: Colors.white54, letterSpacing: 2)),
        Text(value, style: const TextStyle(fontSize: 90, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace')),
        Text(desc, style: TextStyle(color: Colors.red[700], fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _sensorBox(String l, String v, String u, Color c) {
    return Card(
      color: Colors.white.withOpacity(0.03),
      shape: RoundedRectangleBorder(side: BorderSide(color: c.withOpacity(0.3)), borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        Text(v, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: c)),
        Text(u, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ]),
    );
  }

  Widget _actionBtn(String txt, VoidCallback tap, Color c) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(side: BorderSide(color: c), foregroundColor: c),
      onPressed: tap,
      child: Text(txt, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
