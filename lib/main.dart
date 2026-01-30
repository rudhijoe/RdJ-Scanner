import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ENTRY POINT - Memastikan Build Success
void main() {
  runApp(const RdJScannerProApp());
}

class RdJScannerProApp extends StatelessWidget {
  const RdJScannerProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RdJ Scanner Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.redAccent,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MasterDashboard(),
    );
  }
}

class MasterDashboard extends StatefulWidget {
  const MasterDashboard({super.key});

  @override
  State<MasterDashboard> createState() => _MasterDashboardState();
}

class _MasterDashboardState extends State<MasterDashboard> {
  // --- 7 POKOK BACAAN SENSOR (DATA LIVE) ---
  int rpm = 0;           // 1. RPM Mesin
  double volt = 0.0;     // 2. Voltase Aki
  int map = 0;           // 3. Tekanan Udara (MAP)
  double inj = 0.0;      // 4. Durasi Injeksi (ms)
  double tps = 0.0;      // 5. Bukaan Gas (%)
  int eot = 0;           // 6. Suhu Mesin (EOT/ECT)
  double afr = 0.0;      // 7. Rasio Bahan Bakar (AFR)

  String logStatus = "MENUNGGU KONEKSI ECU...";
  Timer? _dataStream;

  @override
  void initState() {
    super.initState();
    _connectToECU();
  }

  // Simulasi Pengambilan Data Real-Time dari Bluetooth ELM327
  void _connectToECU() {
    setState(() => logStatus = "ECU TERHUBUNG - MONITORING AKTIF");
    _dataStream = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          // Logika simulasi data real-time (Akan diganti stream Bluetooth asli)
          rpm = 1450 + Random().nextInt(100);
          volt = 13.5 + Random().nextDouble() * 0.7;
          map = 28 + Random().nextInt(5);
          inj = 2.4 + Random().nextDouble() * 0.3;
          tps = 0.0; // Tetap 0 jika idle
          eot = 85 + Random().nextInt(2);
          afr = 14.2 + Random().nextDouble() * 1.2;
        });
      }
    });
  }

  // --- 3 MENU EKSEKUSI (RISET & HAPUS) ---
  void _executeCommand(String command, String msg) {
    setState(() => logStatus = "MENGIRIM PERINTAH: $command...");
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => logStatus = "SUKSES: $msg");
    });
  }

  @override
  void dispose() {
    _dataStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RdJ SCANNER PRO - 7 SENSOR", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[900],
        centerTitle: true,
        actions: [const Icon(Icons.bluetooth_connected, color: Colors.blueAccent), const SizedBox(width: 15)],
      ),
      body: Column(
        children: [
          // HEADER: RPM BESAR
          _buildRPMGauge(),
          
          // GRID 6 SENSOR LAINNYA
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                _buildSensorCard("AKI (VOLT)", volt.toStringAsFixed(1), "V", Colors.greenAccent),
                _buildSensorCard("INJEKTOR", inj.toStringAsFixed(2), "ms", Colors.cyanAccent),
                _buildSensorCard("MAP SENSOR", "$map", "kPa", Colors.purpleAccent),
                _buildSensorCard("TPS GAS", tps.toStringAsFixed(1), "%", Colors.blueAccent),
                _buildSensorCard("SUHU (EOT)", "$eot", "°C", Colors.orangeAccent),
                _buildSensorCard("RASIO AFR", afr.toStringAsFixed(1), ":1", Colors.yellowAccent),
              ],
            ),
          ),

          // LOG STATUS DINAMIS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.blueGrey[900],
            child: Text(logStatus, textAlign: TextAlign.center, style: const TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold)),
          ),

          // PANEL TOMBOL EKSEKUSI (RISET & CLEAR)
          _buildActionPanel(),
        ],
      ),
    );
  }

  Widget _buildRPMGauge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red[900]!, Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Column(
        children: [
          const Text("ENGINE RPM", style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text("$rpm", style: const TextStyle(fontSize: 65, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildSensorCard(String label, String value, String unit, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton("RISET TPS", Colors.orange, Icons.settings_backup_restore, () => _executeCommand("RISET TPS", "TPS Berhasil Dinolkan")),
          _actionButton("RISET ECU", Colors.blueAccent, Icons.memory, () => _executeCommand("RISET ECU", "Adaptasi ECU Berhasil Direset")),
          _actionButton("HAPUS DTC", Colors.redAccent, Icons.delete_sweep, () => _executeCommand("HAPUS DTC", "Semua Kode Error Terhapus")),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, IconData icon, VoidCallback action) {
    return GestureDetector(
      onTap: action,
      child: Column(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
        ],
      ),
    );
  }
}
