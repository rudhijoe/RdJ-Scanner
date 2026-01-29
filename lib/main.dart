import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class ResetAdvancedPage extends StatefulWidget {
  const ResetAdvancedPage({super.key});

  @override
  State<ResetAdvancedPage> createState() => _ResetAdvancedPageState();
}

class _ResetAdvancedPageState extends State<ResetAdvancedPage> {
  List<double> afrData = List.filled(40, 14.7);
  Timer? _timer;
  bool isMonitoring = false;
  String statusAction = "Sistem Standby - Siap Melakukan Reset";

  // Simulasi Monitoring AFR & O2 Sensor
  void _startMonitoring() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        afrData.removeAt(0);
        afrData.add(13.5 + Random().nextDouble() * 2);
      });
    });
  }

  // Fungsi Kirim Perintah (Placeholder untuk koneksi Bluetooth Anda)
  void _sendCommand(String command, String successMsg) {
    setState(() => statusAction = "Mengirim Perintah $command...");
    // Di sini nanti kita panggil fungsi bluetooth.write(command)
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => statusAction = successMsg);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("RESET & MAINTENANCE"),
        backgroundColor: Colors.red[900],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // PANEL GRAFIK AFR
            _buildSectionTitle("LIVE AIR-FUEL RATIO (AFR)"),
            Container(
              margin: const EdgeInsets.all(15),
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomPaint(
                painter: ChartPainter(afrData, Colors.redAccent),
                child: Container(),
              ),
            ),
            
            // STATUS BOX (DINAMIS)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.blueGrey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10)
              ),
              child: Text(statusAction, 
                style: const TextStyle(color: Colors.yellowAccent, fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            // TOMBOL RESET TPS
            _buildActionCard(
              title: "RESET TPS",
              desc: "Kalibrasi ulang posisi nol katup gas",
              icon: Icons.settings_input_component,
              color: Colors.orange,
              onTap: () => _sendCommand("01 11 RESET", "Berhasil: TPS Kalibrasi ke 0%"),
            ),

            // TOMBOL RESET AFR
            _buildActionCard(
              title: "RESET AFR / FUEL TRIM",
              desc: "Hapus memori adaptasi bahan bakar",
              icon: Icons.ev_station,
              color: Colors.greenAccent,
              onTap: () => _sendCommand("01 03 CLEAR", "Berhasil: Memory AFR dikosongkan"),
            ),

            // TOMBOL CLEAR DTC (FITUR BARU)
            _buildActionCard(
              title: "HAPUS KODE DTC (CLEAR)",
              desc: "Mematikan lampu Check Engine (MIL)",
              icon: Icons.delete_forever,
              color: Colors.redAccent,
              onTap: () => _sendCommand("04", "Berhasil: Semua Kode Error Dihapus"),
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => isMonitoring = !isMonitoring);
                isMonitoring ? _startMonitoring() : _timer?.cancel();
              },
              icon: Icon(isMonitoring ? Icons.stop : Icons.play_arrow),
              label: Text(isMonitoring ? "STOP GRAPH" : "START GRAPH"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildActionCard({required String title, required String desc, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: const Icon(Icons.touch_app, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}

// Grafik Painter
class ChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  ChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    double dx = size.width / (data.length - 1);
    
    path.moveTo(0, size.height - (data[0] * 5)); 
    for (int i = 0; i < data.length; i++) {
      path.lineTo(i * dx, size.height - (data[i] * 5));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
