// Bagian krusial di main.dart untuk data REAL
void _parseOBDData(List<int> rawData) {
  // Mengubah data HEX dari ECU menjadi teks
  String response = utf8.decode(rawData).trim();
  
  // Contoh: Jika ECU membalas "41 0C 0F A0" (Ini kode RPM)
  if (response.contains("41 0C")) {
    List<String> hexParts = response.split(" ");
    // Mengambil byte A dan B (angka ke-3 dan ke-4 dalam respon)
    int a = int.parse(hexParts[2], radix: 16);
    int b = int.parse(hexParts[3], radix: 16);
    
    setState(() {
      // Rumus Standar OBD2 untuk RPM
      rpm = ((a * 256) + b) ~/ 4; 
    });
  }
}
