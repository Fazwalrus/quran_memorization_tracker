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

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
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
      revisedDates = jsonDates
          .map((juz) =>
              (juz as List).map((date) => date != null ? DateTime.parse(date) : null).toList())
          .toList();
    } else {
      revisedDates =
          List.generate(juzCount, (juz) => List.generate(pagesPerJuz[juz], (_) => null));
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
    await prefs.setString(
        'memorization_dates',
        json.encode(revisedDates
            .map((juz) => juz.map((date) => date?.toIso8601String()).toList())
            .toList()));
  }

  void _updateStrength(int juzIndex, int pageIndex) async {
    setState(() {
      data[juzIndex][pageIndex] = (data[juzIndex][pageIndex] + 1) % 6;
      revisedDates[juzIndex][pageIndex] =
          data[juzIndex][pageIndex] > 0 ? DateTime.now() : null;
    });
    await _saveData();
  }

  Color getStrengthColor(int level, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (level) {
      case 0:
        return isDark ? Colors.grey[800]! : Colors.grey[200]!;
      case 1:
        return isDark ? Colors.green[500]! : Colors.green[100]!;
      case 2:
        return isDark ? Colors.green[600]! : Colors.green[300]!;
      case 3:
        return isDark ? Colors.green[700]! : Colors.green[500]!;
      case 4:
        return isDark ? Colors.green[800]! : Colors.green[700]!;
      case 5:
        return isDark ? Colors.green[900]! : Colors.green[900]!;
      default:
        return isDark ? Colors.grey[900]! : Colors.grey[100]!;
    }
  }

  Color getTextColor(int level, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : (level > 2 ? Colors.white : Colors.black);
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
        appBar: AppBar(title: Text('Quran Memorization Tracker')),
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Theme.of(context).cardColor,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: List.generate(6, (level) {
                final labels = [
                  'Not memorized',
                  'Just started',
                  'Learning',
                  'Good',
                  'Strong',
                  'Mastered'
                ];
                return _buildLegendItem(level, labels[level], context);
              }),
            ),
          ),
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
                      padding: const EdgeInsets.all(8),
                      child: Table(
                        defaultColumnWidth: const FixedColumnWidth(70),
                        border: TableBorder.symmetric(
                          inside: BorderSide.none,
                          outside: BorderSide.none,
                        ),
                        children: List.generate(juzCount, (juzIndex) {
                          return TableRow(
                            children: [
                              SizedBox(
                                width: 60,
                                height: 60,
                                child: Center(
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
                                  return GestureDetector(
                                    onTap: () => _updateStrength(juzIndex, pageIndex),
                                    child: Container(
                                      width: 70,
                                      height: 60,
                                      color: getStrengthColor(level, context),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('Pg $pageNum',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: getTextColor(level, context),
                                              )),
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
                                  );
                                } else {
                                  return const SizedBox.shrink();
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