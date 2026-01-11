import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'dart:js_interop';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranMemorizationApp());
}

class QuranMemorizationApp extends StatefulWidget {
  const QuranMemorizationApp({super.key});

  @override
  State<QuranMemorizationApp> createState() => _QuranMemorizationAppState();
}

class _QuranMemorizationAppState extends State<QuranMemorizationApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleThemeMode() {
    setState(() {
      if (_themeMode == ThemeMode.system) {
        _themeMode = ThemeMode.light;
      } else if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

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
      themeMode: _themeMode,
      home: MemorizationGrid(
        themeMode: _themeMode,
        onThemeToggle: _toggleThemeMode,
      ),
    );
  }
}

class MemorizationGrid extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onThemeToggle;
  const MemorizationGrid(
      {super.key, required this.themeMode, required this.onThemeToggle});

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

  // Selection mode state
  bool _selectionMode = false;
  final Set<String> _selectedCells = {};

  // For tap-to-select-range
  int? _rangeStartJuz;
  int? _rangeStartPage;

  String _cellKey(int juz, int page) => '$juz-$page';

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedCells.clear();
    });
  }

  void _toggleCellSelection(int juz, int page) {
    final key = _cellKey(juz, page);
    setState(() {
      if (_selectedCells.contains(key)) {
        _selectedCells.remove(key);
      } else {
        _selectedCells.add(key);
      }
    });
  }

  void _handleRangeTap(int juz, int page) {
    if (!_selectionMode) return;
    setState(() {
      if (_rangeStartJuz == null || _rangeStartPage == null) {
        // First tap: set start
        _rangeStartJuz = juz;
        _rangeStartPage = page;
        _selectedCells.clear();
        _selectedCells.add(_cellKey(juz, page));
      } else {
        // Second tap: select range
        _selectedCells.clear();
        int minJuz = _rangeStartJuz! < juz ? _rangeStartJuz! : juz;
        int maxJuz = _rangeStartJuz! > juz ? _rangeStartJuz! : juz;
        int minPage = _rangeStartPage! < page ? _rangeStartPage! : page;
        int maxPage = _rangeStartPage! > page ? _rangeStartPage! : page;
        for (int j = minJuz; j <= maxJuz; j++) {
          for (int p = minPage; p <= maxPage && p < pagesPerJuz[j]; p++) {
            _selectedCells.add(_cellKey(j, p));
          }
        }
        // Reset for next range selection
        _rangeStartJuz = null;
        _rangeStartPage = null;
      }
    });
  }

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
          data
              .asMap()
              .entries
              .any((entry) => entry.value.length != pagesPerJuz[entry.key])) {
        _initializeDefaultData();
      }
    } else {
      _initializeDefaultData();
    }

    if (savedDates != null) {
      List<dynamic> jsonDates = json.decode(savedDates);
      revisedDates = jsonDates
          .map((juz) => (juz as List)
              .map((date) => date != null ? DateTime.parse(date) : null)
              .toList())
          .toList();
    } else {
      revisedDates = List.generate(
          juzCount, (juz) => List.generate(pagesPerJuz[juz], (_) => null));
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _initializeDefaultData() {
    data = List.generate(
        juzCount, (juz) => List.generate(pagesPerJuz[juz], (_) => 0));
    revisedDates = List.generate(
        juzCount, (juz) => List.generate(pagesPerJuz[juz], (_) => null));
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

  Future<void> _exportToExcel({String? customDirectory}) async {
    try {
      final excel = ex.Excel.createExcel();

      // --- Sheet 1: Page Numbers ---
      final pageSheet = excel['Page numbers'];
      pageSheet
          .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = ex.TextCellValue('');
      for (int page = 0;
          page < pagesPerJuz.reduce((a, b) => a > b ? a : b);
          page++) {
        pageSheet
            .cell(ex.CellIndex.indexByColumnRow(
                columnIndex: page + 1, rowIndex: 0))
            .value = ex.TextCellValue('Page ${page + 1}');
      }
      for (int juz = 0; juz < juzCount; juz++) {
        pageSheet
            .cell(ex.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: juz + 1))
            .value = ex.TextCellValue('Juz ${juz + 1}');
        for (int page = 0; page < pagesPerJuz[juz]; page++) {
          pageSheet
              .cell(ex.CellIndex.indexByColumnRow(
                  columnIndex: page + 1, rowIndex: juz + 1))
              .value = ex.IntCellValue(getPageNumber(juz, page));
        }
      }

      // --- Sheet 2: Scores/Strength ---
      final strengthSheet = excel['Scores'];
      strengthSheet
          .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = ex.TextCellValue('');
      for (int page = 0;
          page < pagesPerJuz.reduce((a, b) => a > b ? a : b);
          page++) {
        strengthSheet
            .cell(ex.CellIndex.indexByColumnRow(
                columnIndex: page + 1, rowIndex: 0))
            .value = ex.TextCellValue('Page ${page + 1}');
      }
      for (int juz = 0; juz < juzCount; juz++) {
        strengthSheet
            .cell(ex.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: juz + 1))
            .value = ex.TextCellValue('Juz ${juz + 1}');
        for (int page = 0; page < pagesPerJuz[juz]; page++) {
          strengthSheet
              .cell(ex.CellIndex.indexByColumnRow(
                  columnIndex: page + 1, rowIndex: juz + 1))
              .value = ex.IntCellValue(data[juz][page]);
        }
      }

      // --- Sheet 3: Last revised ---
      final datesSheet = excel['Last revised'];
      datesSheet
          .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = ex.TextCellValue('');
      for (int page = 0;
          page < pagesPerJuz.reduce((a, b) => a > b ? a : b);
          page++) {
        datesSheet
            .cell(ex.CellIndex.indexByColumnRow(
                columnIndex: page + 1, rowIndex: 0))
            .value = ex.TextCellValue('Page ${page + 1}');
      }
      for (int juz = 0; juz < juzCount; juz++) {
        datesSheet
            .cell(ex.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: juz + 1))
            .value = ex.TextCellValue('Juz ${juz + 1}');
        for (int page = 0; page < pagesPerJuz[juz]; page++) {
          final date = revisedDates[juz][page];
          if (date != null) {
            datesSheet
                .cell(ex.CellIndex.indexByColumnRow(
                    columnIndex: page + 1, rowIndex: juz + 1))
                .value = ex.TextCellValue(_dateFormat.format(date));
          }
        }
      }

      if (excel.sheets.keys.contains('Sheet1')) {
        excel.delete('Sheet1');
      }

      final bytes = excel.encode();
      if (bytes == null) return;

      if (kIsWeb) {
        // --- WEB EXPORT LOGIC ---
        // Convert List<int> to Uint8List so .toJS works
        final Uint8List uint8Bytes = Uint8List.fromList(bytes);

        // Create a blob from the bytes
        final blob = web.Blob(
          [uint8Bytes.toJS].toJS,
          web.BlobPropertyBag(
              type:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
        );

        // Create a temporary URL for the blob
        final url = web.URL.createObjectURL(blob);

        // Create an anchor element and trigger download
        final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
        anchor.href = url;
        anchor.download = 'quran_memorization_data.xlsx';
        anchor.click();

        // Cleanup
        web.URL.revokeObjectURL(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download started in browser')),
          );
        }
      } else {
        // --- MOBILE/DESKTOP EXPORT LOGIC ---
        String filePath;
        if (customDirectory != null) {
          filePath = '$customDirectory/quran_memorization_data.xlsx';
        } else {
          final directory = await getApplicationDocumentsDirectory();
          filePath = '${directory.path}/quran_memorization_data.xlsx';
        }
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Data exported to $filePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e')),
        );
      }
    }
  }

  Future<void> _showExportDialog() async {
    // If on Web, skip the dialog and download immediately
    if (kIsWeb) {
      await _exportToExcel();
      return;
    }

    // If on Mobile/Desktop, show the location picker dialog
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Where do you want to export the Excel file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'default'),
            child: const Text('Default location'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              String? selectedDirectory =
                  await FilePicker.platform.getDirectoryPath();
              navigator.pop(selectedDirectory);
            },
            child: const Text('Choose location...'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (result == 'default') {
      await _exportToExcel();
    } else if (result.isNotEmpty) {
      await _exportToExcel(customDirectory: result);
    }
  }

  Future<void> _importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result != null) {
        final bytes = result.files.single.bytes;
        if (bytes == null) {
          throw Exception("No data received from file");
        }
        final excel = ex.Excel.decodeBytes(bytes);
        // --- Import Scores/Strength ---
        final strengthSheet = excel['Scores'];
        for (int juz = 0; juz < juzCount; juz++) {
          for (int page = 0; page < pagesPerJuz[juz]; page++) {
            final cell = strengthSheet.cell(ex.CellIndex.indexByColumnRow(
                columnIndex: page + 1, rowIndex: juz + 1));
            final value = cell.value;
            String? strValue;
            if (value is ex.IntCellValue) {
              data[juz][page] = value.value;
            } else if (value is ex.TextCellValue) {
              strValue = value.value is String
                  ? value.value as String
                  : (value.value as ex.TextSpan?)?.text;
              data[juz][page] = int.tryParse(strValue ?? '') ?? 0;
            } else if (value is ex.TextSpan) {
              strValue = (value as ex.TextSpan?)?.text;
              data[juz][page] = int.tryParse(strValue ?? '') ?? 0;
            } else {
              data[juz][page] = 0;
            }
          }
        }

        // --- Import Last revised ---
        final datesSheet = excel['Last revised'];
        for (int juz = 0; juz < juzCount; juz++) {
          for (int page = 0; page < pagesPerJuz[juz]; page++) {
            final cell = datesSheet.cell(ex.CellIndex.indexByColumnRow(
                columnIndex: page + 1, rowIndex: juz + 1));
            final value = cell.value;
            String? strValue;
            if (value is ex.TextCellValue) {
              strValue = value.value is String
                  ? value.value as String
                  : (value.value as ex.TextSpan?)?.text;
            } else if (value is ex.TextSpan) {
              strValue = (value as ex.TextSpan?)?.text;
            } else {
              strValue = null;
            }
            if ((strValue?.trim().isNotEmpty ?? false)) {
              try {
                revisedDates[juz][page] = _dateFormat.parse(strValue!);
              } catch (_) {
                revisedDates[juz][page] = null;
              }
            } else {
              revisedDates[juz][page] = null;
            }
          }
        }
        await _saveData();
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data imported successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing data: $e')),
        );
      }
    }
  }

  Future<void> _showEditDialog(int juzIndex, int pageIndex) async {
    int currentStrength = data[juzIndex][pageIndex];
    DateTime? currentDate = revisedDates[juzIndex][pageIndex];
    final TextEditingController strengthController =
        TextEditingController(text: currentStrength.toString());
    DateTime? selectedDate = currentDate;
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Strength & Date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: strengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Strength (0-5)',
              ),
              maxLength: 1,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(selectedDate != null
                      ? 'Date: ${_dateFormat.format(selectedDate!)}'
                      : 'No date'),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? now,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      selectedDate = picked;
                      (context as Element).markNeedsBuild();
                    }
                  },
                  child: const Text('Pick date'),
                ),
                if (selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear date',
                    onPressed: () {
                      selectedDate = null;
                      (context as Element).markNeedsBuild();
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              int? newStrength = int.tryParse(strengthController.text);
              if (newStrength == null || newStrength < 0 || newStrength > 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Strength must be between 0 and 5.')),
                );
                return;
              }
              data[juzIndex][pageIndex] = newStrength;
              revisedDates[juzIndex][pageIndex] =
                  newStrength > 0 ? selectedDate : null;
              _saveData();
              setState(() {});
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    strengthController.dispose();
  }

  Future<void> _showBulkEditDialog() async {
    int? newStrength;
    DateTime? selectedDate;
    final strengthController = TextEditingController();
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Edit Strength & Date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: strengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Strength (0-5)',
              ),
              maxLength: 1,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(selectedDate != null
                      ? 'Date: ${_dateFormat.format(selectedDate!)}'
                      : 'No date'),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? now,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      selectedDate = picked;
                      (context as Element).markNeedsBuild();
                    }
                  },
                  child: const Text('Pick date'),
                ),
                if (selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear date',
                    onPressed: () {
                      selectedDate = null;
                      (context as Element).markNeedsBuild();
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              newStrength = int.tryParse(strengthController.text);
              if (newStrength == null || newStrength! < 0 || newStrength! > 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Strength must be between 0 and 5.')),
                );
                return;
              }
              for (final key in _selectedCells) {
                final parts = key.split('-');
                final juz = int.parse(parts[0]);
                final page = int.parse(parts[1]);
                data[juz][page] = newStrength!;
                revisedDates[juz][page] =
                    newStrength! > 0 ? selectedDate : null;
              }
              _saveData();
              setState(() {
                _selectionMode = false;
                _selectedCells.clear();
              });
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    strengthController.dispose();
  }

  void _showStatsDialog() {
    int totalPages = pagesPerJuz.fold(0, (a, b) => a + b);
    int memorized = 0;
    int mastered = 0;
    for (int j = 0; j < juzCount; j++) {
      for (int p = 0; p < pagesPerJuz[j]; p++) {
        if (data[j][p] > 0) memorized++;
        if (data[j][p] == 5) mastered++;
      }
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Progress Stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total pages: $totalPages'),
            Text(
                'Pages memorized: $memorized (${(memorized / totalPages * 100).toStringAsFixed(1)}%)'),
            Text(
                'Pages mastered: $mastered (${(mastered / totalPages * 100).toStringAsFixed(1)}%)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Tips'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Tap a cell to increment its strength.'),
              Text('• Long-press a cell to manually edit strength/date.'),
              Text(
                  '• Use the Select button to select multiple cells for bulk edit.'),
              Text('• Tap two cells to select a range.'),
              Text(
                  '• Use the import/export buttons to backup or restore your data.'),
              Text(
                  '• Use the theme button to switch between light, dark, and system modes.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Import from Excel'),
                onTap: () {
                  Navigator.pop(context);
                  _importFromExcel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('Export to Excel'),
                onTap: () {
                  Navigator.pop(context);
                  _showExportDialog();
                },
              ),
              ListTile(
                leading: Icon(_themeIcon),
                title: const Text('Theme'),
                subtitle: Text(_themeTooltip),
                onTap: () {
                  widget.onThemeToggle();
                  (context as Element).markNeedsBuild();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  _showAppInfoDialog();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.hasData ? snapshot.data!.version : '...';
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // Larger Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 120, // Increased size
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Quran Memorization Tracker',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('Version $version',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                // Name only appears once here
                const Text(
                  'Created by Syed Fawwaz Hussain',
                  style: TextStyle(fontSize: 14),
                ),
                const Text(
                  '© 2026 All rights reserved',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quran Memorization Tracker')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final maxPages = pagesPerJuz.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Memorization Tracker'),
        actions: [
          IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.select_all),
            onPressed: _toggleSelectionMode,
            tooltip: _selectionMode ? 'Exit selection' : 'Select cells',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _showStatsDialog,
            tooltip: 'Stats',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
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
                notificationPredicate: (notification) =>
                    notification.depth == 1,
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
                        border: const TableBorder.symmetric(
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
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              ...List.generate(maxPages, (pageIndex) {
                                if (pageIndex < pagesPerJuz[juzIndex]) {
                                  int level = data[juzIndex][pageIndex];
                                  int pageNum =
                                      getPageNumber(juzIndex, pageIndex);
                                  DateTime? revisedDate =
                                      revisedDates[juzIndex][pageIndex];
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _selectionMode
                                        ? () =>
                                            _handleRangeTap(juzIndex, pageIndex)
                                        : () => _updateStrength(
                                            juzIndex, pageIndex),
                                    onLongPress: _selectionMode
                                        ? () => _toggleCellSelection(
                                            juzIndex, pageIndex)
                                        : () => _showEditDialog(
                                            juzIndex, pageIndex),
                                    child: Container(
                                      width: 70,
                                      height: 60,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: getStrengthColor(level, context),
                                        border: _selectionMode &&
                                                _selectedCells.contains(
                                                    _cellKey(
                                                        juzIndex, pageIndex))
                                            ? Border.all(
                                                color: Colors.blue, width: 3)
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('Pg $pageNum',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: getTextColor(
                                                    level, context),
                                              )),
                                          Text(
                                            level == 0 ? '' : level.toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color:
                                                  getTextColor(level, context),
                                            ),
                                          ),
                                          if (revisedDate != null)
                                            Text(
                                              _dateFormat.format(revisedDate),
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: getTextColor(
                                                    level, context),
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
          if (_selectionMode && _selectedCells.isNotEmpty)
            FloatingActionButton(
              onPressed: _showBulkEditDialog,
              tooltip: 'Bulk Edit',
              child: const Icon(Icons.edit),
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

  IconData get _themeIcon {
    switch (widget.themeMode) {
      case ThemeMode.light:
        return Icons.wb_sunny;
      case ThemeMode.dark:
        return Icons.nightlight_round;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String get _themeTooltip {
    switch (widget.themeMode) {
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.dark:
        return 'Dark mode';
      case ThemeMode.system:
        return 'System mode';
    }
  }
}
