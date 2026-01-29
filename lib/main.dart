import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false, 
  home: MainMenuPage()
));

// --- HALAMAN MENU UTAMA ---
class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("RdJ DIAGNOSTIC PRO", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.orange[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMenuButton(
              context, 
              "OBD2 SCANNER", 
              Icons.bluetooth_searching, 
              Colors.orange, 
              () => _showMsg(context, "Membuka Scanner...")
            ),
            const SizedBox(height: 20),
            _buildMenuButton(
              context, 
              "CKP SIGNAL MONITOR", 
              Icons.waves, 
              Colors.greenAccent, 
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CKPDiagnosticsPage()))
            ),
            const Spacer(),
            const Text("Status: System Ready", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[900],
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 40),
        label: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }

  void _showMsg(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// --- HALAMAN DIAGNOSTIK CKP (OSKILOSKOP) ---
class CKPDiagnosticsPage extends StatefulWidget {
  const CKPDiagnosticsPage({super.key});
  @override
  State<CKPDiagnosticsPage> createState() => _CKPDiagnosticsPageState();
}

class _CKPDiagnosticsPageState extends State<CKPDiagnosticsPage> {
  List<double> signalData = List.filled(50, 0.0);
  Timer? timer;
  bool isTesting = false;

  void _toggleTest() {
    setState(() {
      isTesting = !isTesting;
      if (isTesting) {
        timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
          setState(() {
            signalData.removeAt(0);
            // Sinyal acak mensimulasikan pulsa magnet kruk as
            signalData.add(Random().nextDouble() * 4); 
          });
        });
      } else {
        timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("CKP MONITOR"), backgroundColor: Colors.green[900]),
      body: Column(
        children: [
          const SizedBox(height: 30),
          const Text("WAVEFORM VISUALIZER", style: TextStyle(color: Colors.greenAccent, letterSpacing: 2)),
          Container(
            margin: const EdgeInsets.all(20),
            height: 250,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
              boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.1), blurRadius: 10)],
            ),
            child: CustomPaint(
              size: Size.infinite,
              painter: WaveformPainter(signalData),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Instruksi: Hubungkan ke OBD2, lalu starter motor. Jika grafik tidak bergerak, sensor CKP atau kabel terputus.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isTesting ? Colors.red : Colors.greenAccent[700],
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            onPressed: _toggleTest,
            child: Text(isTesting ? "STOP MONITOR" : "MULAI CEK CKP", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> data;
  WaveformPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    double dx = size.width / (data.length - 1);
    
    path.moveTo(0, size.height / 2);
    for (int i = 0; i < data.length; i++) {
      path.lineTo(i * dx, (size.height / 2) - (data[i] * 30));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) => true;
}
