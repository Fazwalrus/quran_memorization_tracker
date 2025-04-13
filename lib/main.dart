import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MemorizationGrid(),
    );
  }
}

class MemorizationGrid extends StatefulWidget {
  const MemorizationGrid({super.key});

  @override
  State<MemorizationGrid> createState() => _MemorizationGridState();
}

class _MemorizationGridState extends State<MemorizationGrid> {
  final int juzCount = 30;
  late List<List<int>> data;
  late List<List<DateTime?>> revisedDates;
  late List<int> pagesPerJuz;
  bool _isLoading = true;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('MMM d');

  @override
  void initState() {
    super.initState();
    pagesPerJuz = List.generate(juzCount, (index) {
      if (index == 0) return 21;
      if (index == 29) return 23;
      return 20;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('memorization_data');
    String? savedDates = prefs.getString('memorization_dates');

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

    if (savedDates != null) {
      List<dynamic> jsonDates = json.decode(savedDates);
      revisedDates = jsonDates.map((juz) => 
        (juz as List).map((date) => date != null ? DateTime.parse(date) : null).toList()
      ).toList();
    } else {
      revisedDates = List.generate(juzCount, (juz) => List.generate(pagesPerJuz[juz], (_) => null));
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _initializeDefaultData() {
    data = List.generate(juzCount, (juz) => List.generate(pagesPerJuz[juz], (_) => 0));
    revisedDates = List.generate(juzCount, (juz) => List.generate(pagesPerJuz[juz], (_) => null));
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('memorization_data', json.encode(data));
    await prefs.setString('memorization_dates', json.encode(
      revisedDates.map((juz) => juz.map((date) => date?.toIso8601String()).toList()).toList()
    ));
  }

  void _updateStrength(int juzIndex, int pageIndex) async {
    setState(() {
      data[juzIndex][pageIndex] = (data[juzIndex][pageIndex] + 1) % 6;
      if (data[juzIndex][pageIndex] > 0) {
        revisedDates[juzIndex][pageIndex] = DateTime.now();
      } else {
        revisedDates[juzIndex][pageIndex] = null;
      }
    });
    await _saveData();
  }

  Color getStrengthColor(int level, BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    switch (level) {
      case 0:
        return isDark ? Colors.grey[800]! : Colors.grey[200]!;
      case 1: return isDark ? Colors.green[500]! : Colors.green[100]!;
      case 2: return isDark ? Colors.green[600]! : Colors.green[300]!;
      case 3: return isDark ? Colors.green[700]! : Colors.green[500]!;
      case 4: return isDark ? Colors.green[800]! : Colors.green[700]!;
      case 5: return isDark ? Colors.green[900]! : Colors.green[900]!;
      default:
        return isDark ? Colors.grey[900]! : Colors.grey[100]!;
    }
  }

  Color getTextColor(int level, BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return level < 3 ? Colors.white : Colors.white;
    } else {
      return level > 2 ? Colors.white : Colors.black;
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
            color: Theme.of(context).cardColor,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: [
                _buildLegendItem(0, "Not memorized", context),
                _buildLegendItem(1, "Just started", context),
                _buildLegendItem(2, "Learning", context),
                _buildLegendItem(3, "Good", context),
                _buildLegendItem(4, "Strong", context),
                _buildLegendItem(5, "Mastered", context),
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
                        dataRowHeight: 60,
                        columns: [
                          const DataColumn(
                            label: SizedBox(
                              width: 60,
                              child: Text('', textAlign: TextAlign.center)),
                          ),
                          ...List.generate(maxPages, (i) => DataColumn(
                            label: SizedBox(
                              width: 70,
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
                                  DateTime? revisedDate = revisedDates[juzIndex][pageIndex];
                                  return DataCell(
                                    GestureDetector(
                                      onTap: () => _updateStrength(juzIndex, pageIndex),
                                      child: Container(
                                        width: 70,
                                        height: 60,
                                        color: getStrengthColor(level, context),
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Pg $pageNum',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: getTextColor(level, context),
                                              ),
                                            ),
                                            Text(
                                              level == 0 ? '' : level.toString(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: getTextColor(level, context),
                                              ),
                                            ),
                                            if (revisedDate != null)
                                              Text(
                                                _dateFormat.format(revisedDate),
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  color: getTextColor(level, context),
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

  Widget _buildLegendItem(int level, String label, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          color: getStrengthColor(level, context),
          margin: const EdgeInsets.only(right: 4),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}