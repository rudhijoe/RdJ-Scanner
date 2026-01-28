import 'dart:async';
import 'dart:convert';
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
      title: 'RdJ Scanner Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.orbitronTextTheme(Theme.of(context).textTheme),
      ),
      home: const ScannerHomePage(),
    );
  }
}

class ScannerHomePage extends StatefulWidget {
  const ScannerHomePage({super.key});

  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  BluetoothDevice? connectedDevice;
  String afrValue = "0.0";
  StreamSubscription? scanSubscription;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  // Minta Izin Bluetooth & Lokasi (Wajib untuk Android 12+)
  void requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  void startScan() async {
    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    // Mulai scan
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // Dapatkan hasil scan
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          scanResults = results;
        });
      }
    });

    await Future.delayed(const Duration(seconds: 10));
    if (mounted) setState(() => isScanning = false);
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() => connectedDevice = device);
      // Simulasi pembacaan data AFR dari ELM327
      startDataSimulation();
    } catch (e) {
      debugPrint("Koneksi gagal: $e");
    }
  }

  void startDataSimulation() {
    // Di sini nanti tempat logika AT Commands OBD2
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          // Simulasi angka AFR bergerak antara 12.0 - 15.0
          afrValue = (12 + (DateTime.now().millisecond / 333)).toStringAsFixed(1);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RdJ SCANNER PRO'),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Display AFR Utama
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.orange, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("AIR FUEL RATIO", style: TextStyle(color: Colors.white, fontSize: 18)),
                Text(
                  afrValue,
                  style: const TextStyle(color: Colors.orange, fontSize: 80, fontWeight: FontWeight.bold),
                ),
                Text(
                  connectedDevice == null ? "DISCONNECTED" : "CONNECTED: ${connectedDevice!.platformName}",
                  style: TextStyle(color: connectedDevice == null ? Colors.red : Colors.green),
                ),
              ],
            ),
          ),
          
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(isScanning ? "SCANNING..." : "SCAN DEVICE"),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final r = scanResults[index];
                return ListTile(
                  title: Text(r.device.platformName.isEmpty ? "Unknown Device" : r.device.platformName),
                  subtitle: Text(r.device.remoteId.toString()),
                  trailing: const Icon(Icons.bluetooth, color: Colors.blue),
                  onTap: () => connectToDevice(r.device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
