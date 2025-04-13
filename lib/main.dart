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
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
    data = List.generate(juzCount, (juz) => List.generate(pagesPerJuz[juz], (_) => 0));
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('memorization_data', json.encode(data));
  }

  void _updateStrength(int juzIndex, int pageIndex) async {
    setState(() {
      data[juzIndex][pageIndex] = (data[juzIndex][pageIndex] + 1) % 6;
    });
    await _saveData();
  }

  Color getStrengthColor(int level) {
    switch (level) {
      case 0:
        return Colors.grey[200]!;
      case 1:
        return Colors.green[100]!;
      case 2:
        return Colors.green[300]!;
      case 3:
        return Colors.green[500]!;
      case 4:
        return Colors.green[700]!;
      case 5:
        return Colors.green[900]!;
      default:
        return Colors.grey;
    }
  }

  int getPageNumber(int juzIndex, int pageIndex) {
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

    int maxPages = pagesPerJuz.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Memorization Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset All Data'),
                  content: const Text('Are you sure you want to reset all memorization data?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        _initializeDefaultData();
                        _saveData();
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Legend
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.grey[100],
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: [
                _buildLegendItem(0, "Not memorized"),
                _buildLegendItem(1, "Just started"),
                _buildLegendItem(2, "Learning"),
                _buildLegendItem(3, "Good"),
                _buildLegendItem(4, "Strong"),
                _buildLegendItem(5, "Mastered"),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: Scrollbar(
              controller: _verticalScrollController,
              thumbVisibility: true,
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                notificationPredicate: (notification) => notification.depth == 1,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DataTable(
                        columnSpacing: 0,
                        horizontalMargin: 0,
                        headingRowHeight: 40,
                        dataRowHeight: 50, // Slightly taller to accommodate page numbers
                        columns: [
                          const DataColumn(
                            label: SizedBox(
                              width: 60,
                              child: Text('Juz', textAlign: TextAlign.center)),
                          ),
                          ...List.generate(maxPages, (i) => DataColumn(
                            label: SizedBox(
                              width: 60, // Wider to accommodate page numbers
                              child: Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )),
                        ],
                        rows: List.generate(juzCount, (juzIndex) {
                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    'Juz ${juzIndex + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              ...List.generate(maxPages, (pageIndex) {
                                if (pageIndex < pagesPerJuz[juzIndex]) {
                                  int level = data[juzIndex][pageIndex];
                                  int pageNum = getPageNumber(juzIndex, pageIndex);
                                  return DataCell(
                                    GestureDetector(
                                      onTap: () => _updateStrength(juzIndex, pageIndex),
                                      child: Container(
                                        width: 60,
                                        height: 50,
                                        color: getStrengthColor(level),
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Pg $pageNum',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: level > 2 ? Colors.white : Colors.black,
                                              ),
                                            ),
                                            Text(
                                              level == 0 ? '' : level.toString(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: level > 2 ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  return const DataCell(SizedBox.shrink());
                                }
                              }),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(int level, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          color: getStrengthColor(level),
          margin: const EdgeInsets.only(right: 4),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}