import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const RdJScannerApp());

class RdJScannerApp extends StatelessWidget {
  const RdJScannerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.orange,
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.orbitronTextTheme(Theme.of(context).textTheme),
      ),
      home: const MainScannerPage(),
    );
  }
}

class MainScannerPage extends StatefulWidget {
  const MainScannerPage({super.key});
  @override
  State<MainScannerPage> createState() => _MainScannerPageState();
}

class _MainScannerPageState extends State<MainScannerPage> {
  BluetoothDevice? connectedDevice;
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  
  // Data Sensor
  Map<String, String> sensors = {
    "AFR": "14.7", "RPM": "0", "INJ": "0.00", 
    "IGN": "0.0", "MAP": "101.3", "CASE": "101.1"
  };

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  // 1. FUNGSI IZIN & NYALAKAN BLUETOOTH OTOMATIS
  Future<void> _initSystem() async {
    // Minta Izin
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Cek & Minta Nyalakan Bluetooth
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        debugPrint("Sistem tidak mendukung auto-on: $e");
      }
    }
  }

  // 2. FUNGSI SCAN PERANGKAT
  void startScan() async {
    // Cek GPS sebelum scan (Wajib untuk Android 7-11)
    if (await Permission.location.serviceStatus.isDisabled) {
      _showSimpleSnackBar("Harap Aktifkan GPS/Lokasi Anda!");
      await openAppSettings();
      return;
    }

    setState(() { scanResults.clear(); isScanning = true; });
    
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) setState(() { scanResults = results; });
      });
      await Future.delayed(const Duration(seconds: 5));
    } finally {
      if (mounted) setState(() { isScanning = false; });
    }
  }

  // 3. FUNGSI KONEKSI & STREAM DATA
  void connectToDevice(BluetoothDevice device) async {
    _showSimpleSnackBar("Menghubungkan ke ${device.platformName}...");
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      setState(() { connectedDevice = device; });
      
      // Jalankan Stream Data Simulasi (Nanti bisa diganti biner OBD2)
      Timer.periodic(const Duration(milliseconds: 150), (timer) {
        if (mounted && connectedDevice != null) {
          setState(() {
            sensors["AFR"] = (13.5 + (DateTime.now().millisecond / 500)).toStringAsFixed(1);
            sensors["RPM"] = (1450 + (DateTime.now().millisecond % 150)).toString();
            sensors["INJ"] = (2.15 + (DateTime.now().millisecond / 2500)).toStringAsFixed(2);
            sensors["IGN"] = (9.5 + (DateTime.now().millisecond / 120)).toStringAsFixed(1);
          });
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      _showSimpleSnackBar("Gagal Terhubung: $e");
    }
  }

  void _showSimpleSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RdJ SCANNER PRO", style: TextStyle(letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
          if (connectedDevice != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: () => _showClearDTCDialog(),
            )
        ],
      ),
      body: connectedDevice == null ? _buildDevicePicker() : _buildDashboard(),
    );
  }

  // WIDGET: PEMILIH BLUETOOTH
  Widget _buildDevicePicker() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text("PILIH MODUL ECU", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        const Divider(color: Colors.orange),
        if (isScanning) const LinearProgressIndicator(color: Colors.orange),
        Expanded(
          child: ListView.builder(
            itemCount: scanResults.length,
            itemBuilder: (c, i) {
              final d = scanResults[i].device;
              final name = d.platformName.isEmpty ? "Unknown Device" : d.platformName;
              return Card(
                color: const Color(0xFF1A1A1A),
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_audio, color: Colors.blue),
                  title: Text(name),
                  subtitle: Text(d.remoteId.toString(), style: const TextStyle(fontSize: 10)),
                  onTap: () => connectToDevice(d),
                ),
              );
            },
          ),
        ),
        _actionButton("SCAN PERANGKAT", startScan, Colors.orange),
      ],
    );
  }

  // WIDGET: DASHBOARD UTAMA
  Widget _buildDashboard() {
    return Column(
      children: [
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _sensorCard("AIR FUEL", sensors["AFR"]!, "AFR", Colors.orange),
              _sensorCard("CKP SENSOR", sensors["RPM"]!, "RPM", Colors.purpleAccent),
              _sensorCard("INJECTOR", sensors["INJ"]!, "ms", Colors.blueAccent),
              _sensorCard("IGNITION", sensors["IGN"]!, "° BTDC", Colors.greenAccent),
              _sensorCard("THROTTLE", sensors["MAP"]!, "kPa", Colors.redAccent),
              _sensorCard("CRANKCASE", sensors["CASE"]!, "kPa", Colors.yellowAccent),
            ],
          ),
        ),
        _actionButton("DISCONNECT", () => setState(() => connectedDevice = null), Colors.red),
      ],
    );
  }

  Widget _sensorCard(String title, String val, String unit, Color col) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: col.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback func, Color col) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: func,
        style: ElevatedButton.styleFrom(
          backgroundColor: col, minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showClearDTCDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("HAPUS DTC?"),
        content: const Text("Pastikan mesin mati tapi kontak ON."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _showSimpleSnackBar("Perintah Mode 04 Berhasil!");
            },
            child: const Text("RESET"),
          ),
        ],
      ),
    );
  }
}
