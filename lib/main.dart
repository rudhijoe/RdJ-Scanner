import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const RdJScannerApp());
}

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
      home: const PermissionCheckPage(),
    );
  }
}

// --- HALAMAN IZIN ---
class PermissionCheckPage extends StatefulWidget {
  const PermissionCheckPage({super.key});
  @override
  State<PermissionCheckPage> createState() => _PermissionCheckPageState();
}

class _PermissionCheckPageState extends State<PermissionCheckPage> {
  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  void checkPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location
    ].request();
    if (mounted) {
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const ScannerHomePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Colors.orange)),
    );
  }
}

// --- DASHBOARD UTAMA ---
class ScannerHomePage extends StatefulWidget {
  const ScannerHomePage({super.key});
  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  final StreamController<Map<String, String>> _dataStreamController = StreamController.broadcast();
  bool isConnected = false;
  
  Map<String, String> sensors = {
    "AFR": "14.7",
    "INJECTOR": "2.20",
    "IGNITION": "10.0",
    "MAP (TB)": "30.0",
    "CKP (RPM)": "1500",
    "CRANKCASE": "101.3",
  };

  void startStreaming() {
    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted && isConnected) {
        setState(() {
          sensors["AFR"] = (13.5 + (DateTime.now().millisecond / 500)).toStringAsFixed(1);
          sensors["CKP (RPM)"] = (1450 + (DateTime.now().millisecond % 200)).toString();
          sensors["INJECTOR"] = (2.10 + (DateTime.now().millisecond / 2000)).toStringAsFixed(2);
          sensors["IGNITION"] = (8.0 + (DateTime.now().millisecond / 100)).toStringAsFixed(1);
          sensors["MAP (TB)"] = (28.5 + (DateTime.now().millisecond / 1000)).toStringAsFixed(1);
          sensors["CRANKCASE"] = (101.0 + (DateTime.now().millisecond / 2000)).toStringAsFixed(1);
        });
        _dataStreamController.add(sensors);
      }
    });
  }

  void clearDTC() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("HAPUS DTC / RESET ECU?"),
        content: const Text("Pastikan mesin OFF & Kontak ON."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("DTC Berhasil Dihapus!"))
              );
            },
            child: const Text("RESET NOW"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RdJ PRO SCANNER"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: clearDTC)
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<Map<String, String>>(
              stream: _dataStreamController.stream,
              builder: (context, snapshot) {
                var data = snapshot.data ?? sensors;
                return GridView.count(
                  padding: const EdgeInsets.all(10),
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _sensorTile("AIR FUEL", data["AFR"]!, "AFR", Colors.orange),
                    _sensorTile("CKP SENSOR", data["CKP (RPM)"]!, "RPM", Colors.purpleAccent),
                    _sensorTile("INJECTOR", data["INJECTOR"]!, "ms", Colors.blueAccent),
                    _sensorTile("IGNITION", data["IGNITION"]!, "°", Colors.greenAccent),
                    _sensorTile("THROTTLE PRESS", data["MAP (TB)"]!, "kPa", Colors.redAccent),
                    _sensorTile("CRANKCASE", data["CRANKCASE"]!, "kPa", Colors.yellowAccent),
                  ],
                );
              },
            ),
          ),
          _buildConnectButton(),
        ],
      ),
    );
  }

  Widget _sensorTile(String label, String value, String unit, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildConnectButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: () {
          if (!isConnected) startStreaming();
          setState(() => isConnected = !isConnected);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isConnected ? Colors.red : Colors.orange,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(isConnected ? "DISCONNECT" : "CONNECT ECU", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
