import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// PINTU MASUK APLIKASI - Menghindari Error "No main method found"
void main() {
  runApp(const RdJScannerApp());
}

class RdJScannerApp extends StatelessWidget {
  const RdJScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RdJ Scanner Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.redAccent,
      ),
      home: const RdJScannerDashboard(),
    );
  }
}

class RdJScannerDashboard extends StatefulWidget {
  const RdJScannerDashboard({super.key});

  @override
  State<RdJScannerDashboard> createState() => _RdJScannerDashboardState();
}

class _RdJScannerDashboardState extends State<RdJScannerDashboard> {
  // DATA SENSOR
  double voltaseAki = 12.6;
  int suhuMesin = 85; // Suhu sensor ECT/EOT
  String statusAction = "Sistem Standby - Menunggu Perintah";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSimulasiSensor();
  }

  // Simulasi data dari ELM327
  void _startSimulasiSensor() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          // Simulasi Aki (13.0V - 14.5V)
          voltaseAki = 13.2 + Random().nextDouble() * 1.0;
          // Simulasi Suhu Mesin (Bisa naik pelan-pelan)
          if (suhuMesin < 105) suhuMesin += Random().nextInt(2);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _executeCommand(String command, String successMsg) {
    setState(() => statusAction = "Memproses $command...");
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => statusAction = "SUKSES: $successMsg");
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isOverheat = suhuMesin > 100;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("RdJ SCANNER DASHBOARD", style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.blueGrey[900],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- ROW SENSOR UTAMA (AKI & SUHU) ---
            Row(
              children: [
                // MONITOR AKI
                Expanded(
                  child: _buildSensorTile(
                    "VOLT AKI", 
                    "${voltaseAki.toStringAsFixed(1)}V", 
                    voltaseAki < 12.0 ? Colors.red : Colors.greenAccent
                  ),
                ),
                const SizedBox(width: 10),
                // MONITOR SUHU (ECT)
                Expanded(
                  child: _buildSensorTile(
                    "SUHU MESIN", 
                    "$suhuMesin°C", 
                    isOverheat ? Colors.red : Colors.orangeAccent
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),
            
            // STATUS BAR
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey[900], 
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10)
              ),
              child: Text(statusAction, 
                style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            ),

            const SizedBox(height: 25),

            // --- MENU PEMELIHARAAN ---
            _buildSectionHeader("MAINTENANCE & RESET"),
            _buildActionCard("RESET TPS", "Kalibrasi bukaan gas nol", Icons.settings_backup_restore, Colors.blue),
            _buildActionCard("RESET AFR", "Kembalikan rasio bensin standar", Icons.ev_station, Colors.green),
            _buildActionCard("CLEAR DTC", "Hapus kode error & MIL", Icons.auto_delete, Colors.red),
            
            const SizedBox(height: 30),
            const Text("RdJ PRO v1.0.2 - Pemalang Tech", style: TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 10),
        child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildActionCard(String title, String desc, IconData icon, Color color) {
    return Card(
      color: Colors.white.withOpacity(0.03),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white12),
        onTap: () => _executeCommand(title, "$title Berhasil Dilakukan"),
      ),
    );
  }
}
