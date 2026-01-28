import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    theme: ThemeData.dark().copyWith(primaryColor: Colors.redAccent),
    home: RdJScanner(),
    debugShowCheckedModeBanner: false,
  ));
}

class RdJScanner extends StatefulWidget {
  @override
  _RdJScannerState createState() => _RdJScannerState();
}

class _RdJScannerState extends State<RdJScanner> {
  BluetoothConnection? connection;
  bool isConnecting = false;
  bool isLogging = false;
  String status = "Terputus";
  
  // Data Sensor Real-time
  double rpm = 0, speed = 0, temp = 0, afr = 14.7;
  List<List<dynamic>> logData = [["Waktu", "RPM", "Speed", "Suhu", "AFR"]];

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  void _initPermissions() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location, Permission.storage].request();
    WakelockPlus.enable();
  }

  // Koneksi & Handshake
  void connectOBD() async {
    setState(() => isConnecting = true);
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice dev = devices.firstWhere((d) => d.name == "OBDII");

      connection = await BluetoothConnection.toAddress(dev.address);
      setState(() => status = "Setting Protocol...");

      await _sendRaw("AT Z\r");    
      await _sendRaw("AT E0\r");   
      await _sendRaw("AT SP 0\r"); 
      
      setState(() { status = "RdJ Connected"; isConnecting = false; });
      _listenData();
      _startPolling();
    } catch (e) {
      setState(() { status = "Gagal: Periksa Bluetooth"; isConnecting = false; });
    }
  }

  // Mendengarkan Balasan dari Motor
  void _listenData() {
    connection!.input!.listen((Uint8List data) {
      String response = utf8.decode(data);
      _parseResponse(response);
    }).onDone(() => setState(() => status = "Terputus"));
  }

  void _parseResponse(String res) {
    if (res.contains("41 0C")) { // Respon RPM
      List<String> parts = res.split(" ");
      int a = int.parse(parts[2], radix: 16);
      int b = int.parse(parts[3], radix: 16);
      setState(() => rpm = ((a * 256) + b) / 4);
    }
    // Tambahkan parsing PID lain di sini sesuai rumus sebelumnya
  }

  void _startPolling() async {
    while (connection != null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(utf8.encode("01 0C\r"))); // Request RPM
      await Future.delayed(Duration(milliseconds: 200));
      connection!.output.add(Uint8List.fromList(utf8.encode("01 0D\r"))); // Request Speed
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  Future<void> _sendRaw(String cmd) async {
    connection!.output.add(Uint8List.fromList(utf8.encode(cmd)));
    await connection!.output.allSent;
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text("RdJ SCANNER"), backgroundColor: Colors.red),
      body: Column(
        children: [
          _statusTile(),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.all(10),
              children: [
                _card("RPM", rpm.toStringAsFixed(0), "RPM", Colors.redAccent),
                _card("AFR", afr.toStringAsFixed(1), "Ratio", afr > 15 ? Colors.red : Colors.green),
              ],
            ),
          ),
          ElevatedButton(onPressed: connectOBD, child: Text("HUBUNGKAN KE MOTOR"))
        ],
      ),
    );
  }

  Widget _statusTile() => Container(color: Colors.white10, child: ListTile(title: Text(status, style: TextStyle(color: Colors.green))));
  Widget _card(String t, String v, String u, Color c) => Card(color: Colors.white12, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(t), Text(v, style: TextStyle(fontSize: 40, color: c)), Text(u)]));
}
