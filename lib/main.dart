import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranMemorizationApp());
}

class QuranMemorizationApp extends StatelessWidget {
  const QuranMemorizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Memorization Tracker',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MemorizationGrid(),
    );
  }
}

class MemorizationGrid extends StatefulWidget {
  const MemorizationGrid({super.key});

  @override
  MemorizationGridState createState() => MemorizationGridState();
}

class MemorizationGridState extends State<MemorizationGrid> {
  final int juzCount = 30;
  late List<List<int>> data;
  late List<int> pagesPerJuz;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize the correct number of pages for each juz
    pagesPerJuz = List.generate(juzCount, (index) {
      if (index == 0) return 21;    // Juz 1 has 21 pages
      if (index == 29) return 23;   // Juz 30 has 23 pages
      return 20;                    // Juz 2-29 have 20 pages
    });
    _loadData();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('memorization_data');

    if (savedData != null) {
      List<dynamic> jsonData = json.decode(savedData);
      data = jsonData.map((row) => List<int>.from(row)).toList();
      
      // Validate data structure matches our pagesPerJuz configuration
      if (data.length != juzCount || 
          data.asMap().entries.any((entry) => entry.value.length != pagesPerJuz[entry.key])) {
        _initializeDefaultData();
      }
    } else {
      _initializeDefaultData();
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _initializeDefaultData() {
    data = List.generate(juzCount, (juz) => List.generate(pagesPerJuz[juz], (_) => 1));
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('memorization_data', json.encode(data));
  }

  void _updateStrength(int juzIndex, int pageIndex) async {
    setState(() {
      data[juzIndex][pageIndex] = (data[juzIndex][pageIndex] % 5) + 1;
    });
    await _saveData();
  }

  Color getStrengthColor(int level) {
    switch (level) {
      case 1:
        return Colors.green[100]!;
      case 2:
        return Colors.green[200]!;
      case 3:
        return Colors.green[400]!;
      case 4:
        return Colors.green[600]!;
      case 5:
        return Colors.green[800]!;
      default:
        return Colors.grey;
    }
  }

  int getPageNumber(int juzIndex, int pageIndex) {
    // Calculate the actual Quran page number
    int pageNumber = 1;
    for (int i = 0; i < juzIndex; i++) {
      pageNumber += pagesPerJuz[i];
    }
    return pageNumber + pageIndex;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quran Memorization Tracker')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Find the maximum number of pages in any juz for column generation
    int maxPages = pagesPerJuz.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Memorization Tracker'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(1, "New"),
                _buildLegendItem(2, "Learning"),
                _buildLegendItem(3, "Good"),
                _buildLegendItem(4, "Strong"),
                _buildLegendItem(5, "Mastered"),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Juz')),
              ...List.generate(maxPages, (i) {
                // Only show column label if this page exists in at least one juz
                return DataColumn(
                  label: Text('Pg ${i + 1}'),
                  tooltip: 'Page ${i + 1}',
                );
              }),
            ],
            rows: List.generate(juzCount, (juzIndex) {
              return DataRow(cells: [
                DataCell(Text('Juz ${juzIndex + 1}')),
                ...List.generate(maxPages, (pageIndex) {
                  // Only show cell if this page exists in this juz
                  if (pageIndex < pagesPerJuz[juzIndex]) {
                    int level = data[juzIndex][pageIndex];
                    int pageNum = getPageNumber(juzIndex, pageIndex);
                    return DataCell(
                      GestureDetector(
                        onTap: () => _updateStrength(juzIndex, pageIndex),
                        child: Container(
                          color: getStrengthColor(level),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            children: [
                              Text('Pg $pageNum', 
                                  style: const TextStyle(fontSize: 10)),
                              Text(level.toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    return const DataCell(Text(''));
                  }
                })
              ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(int level, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          color: getStrengthColor(level),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}