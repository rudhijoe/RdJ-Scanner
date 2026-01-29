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
      theme: ThemeData(brightness: Brightness.dark, primaryColor: Colors.orange,
      textTheme: GoogleFonts.orbitronTextTheme(Theme.of(context).textTheme)),
      home: const PermissionCheckPage(),
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
  // Variabel Data Sensor
  Map<String, String> sensors = {
    "AFR": "14.7",
    "INJECTOR": "2.20",
    "IGNITION": "10.0",
    "MAP (TB)": "30.0",
    "CKP (RPM)": "1500",
    "CRANKCASE": "101.3",
  };
  
  bool isConnected = false;

  void simulateData() {
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (mounted && isConnected) {
        setState(() {
          sensors["AFR"] = (13.5 + (DateTime.now().millisecond / 500)).toStringAsFixed(1);
          sensors["INJECTOR"] = (2.10 + (DateTime.now().millisecond / 2000)).toStringAsFixed(2);
          sensors["IGNITION"] = (8.0 + (DateTime.now().millisecond / 100)).toStringAsFixed(1);
          sensors["MAP (TB)"] = (28 + (DateTime.now().millisecond / 100)).toStringAsFixed(1);
          sensors["CKP (RPM)"] = (1450 + (DateTime.now().millisecond % 100)).toString();
          sensors["CRANKCASE"] = (100 + (DateTime.now().millisecond / 1000)).toStringAsFixed(1);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("RdJ PRO SCANNER", style: TextStyle(fontSize: 18)),
        centerTitle: true, backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(10),
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _sensorTile("AIR FUEL", sensors["AFR"]!, "AFR", Colors.orange),
                _sensorTile("INJECTOR", sensors["INJECTOR"]!, "ms", Colors.blueAccent),
                _sensorTile("IGNITION", sensors["IGNITION"]!, "°", Colors.greenAccent),
                _sensorTile("THROTTLE PRESS", sensors["MAP (TB)"]!, "kPa", Colors.redAccent),
                _sensorTile("CKP SENSOR", sensors["CKP (RPM)"]!, "RPM", Colors.purpleAccent),
                _sensorTile("CRANKCASE", sensors["CRANKCASE"]! , "kPa", Colors.yellowAccent),
              ],
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
          Text(value, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
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
          if (!isConnected) simulateData();
          setState(() => isConnected = !isConnected);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isConnected ? Colors.red : Colors.orange,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
        ),
        child: Text(isConnected ? "STOP SCAN" : "START SCAN"),
      ),
    );
  }
}

// --- PERMISSION PAGE (Tetap seperti sebelumnya) ---
class PermissionCheckPage extends StatefulWidget {
  const PermissionCheckPage({super.key});
  @override State<PermissionCheckPage> createState() => _PermissionCheckPageState();
}
class _PermissionCheckPageState extends State<PermissionCheckPage> {
  @override void initState() { super.initState(); checkPermissions(); }
  void checkPermissions() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ScannerHomePage()));
  }
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
}
