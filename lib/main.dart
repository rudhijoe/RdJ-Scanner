// ... (Bagian import tetap sama)

class _ScannerHomePageState extends State<ScannerHomePage> {
  // Gunakan StreamController untuk menangani data real-time
  final StreamController<Map<String, String>> _dataStreamController = StreamController.broadcast();
  
  Map<String, String> sensors = {
    "AFR": "14.7", "INJECTOR": "2.20", "IGNITION": "10.0",
    "MAP (TB)": "30.0", "CKP (RPM)": "1500", "CRANKCASE": "101.3",
  };
  
  bool isConnected = false;

  // FUNGSI STREAM: Data mengalir tanpa henti
  void startStreaming() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) { // Lebih cepat (100ms)
      if (mounted && isConnected) {
        // Simulasi logika pengolahan data biner dari ELM327
        sensors["AFR"] = (13.5 + (DateTime.now().millisecond / 500)).toStringAsFixed(1);
        sensors["CKP (RPM)"] = (1450 + (DateTime.now().millisecond % 100)).toString();
        // ... (sensor lainnya)
        
        _dataStreamController.add(sensors);
      }
    });
  }

  // FUNGSI HAPUS DTC (RESET ECU)
  void clearDTC() async {
    // Di dunia nyata, kita mengirim perintah "04" ke Bluetooth
    // Perintah "04" adalah standar internasional untuk Clear Diagnostic Data
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("HAPUS DTC / RESET ECU?"),
        content: const Text("Pastikan mesin dalam kondisi mati tapi kontak tetap ON."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Simulasi pengiriman kode '04' ke ELM327
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Perintah 04 Terkirim: DTC Berhasil Dihapus!"))
              );
            }, 
            child: const Text("HAPUS SEKARANG")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("RdJ PRO STREAM"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: clearDTC, // Tombol Hapus DTC
            tooltip: "Hapus Kode Kerusakan",
          )
        ],
      ),
      body: StreamBuilder<Map<String, String>>(
        stream: _dataStreamController.stream,
        builder: (context, snapshot) {
          var currentData = snapshot.data ?? sensors;
          return Column(
            children: [
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.all(10),
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  children: [
                    _sensorTile("AIR FUEL", currentData["AFR"]!, "AFR", Colors.orange),
                    _sensorTile("CKP SENSOR", currentData["CKP (RPM)"]!, "RPM", Colors.purpleAccent),
                    // ... tambahkan sensor lainnya di sini
                  ],
                ),
              ),
              _buildConnectButton(),
            ],
          );
        }
      ),
    );
  }
  // ... (Widget pendukung lainnya tetap sama)
}
