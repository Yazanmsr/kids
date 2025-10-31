import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// main.dart (or a separate utils.dart file)
import 'package:flutter/services.dart';

Future<void> requestBatteryOptimizationsPermission() async {
  const platform = MethodChannel('battery_optimizations');
  try {
    await platform.invokeMethod('requestIgnoreBatteryOptimizations');
  } on PlatformException catch (e) {
    print("Error: ${e.message}");
  }
}

const platform = MethodChannel('screen_capture_channel');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizationsDelegate(),
      ],
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> screenshots = [];
  bool isProjectionRunning = false;

  @override
  void initState() {
    super.initState();
    requestBatteryOptimizationsPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServiceStatus();
      _loadScreenshots();
    });
  }

  Future<void> _checkServiceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final running  = prefs.getBool("service_running");


    setState(() {
      isProjectionRunning = running ?? false;
    });
  }


  Future<void> _toggleProjection() async {
    final loc = AppLocalizations.of(context);

    if (isProjectionRunning) {
      try {
        await platform.invokeMethod("stopProjection");
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("service_running", false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.stopped)),
        );
        setState(() {
          isProjectionRunning = false;
        });
      } on PlatformException catch (e) {
        print("❌ Failed to stop projection: ${e.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to stop projection: ${e.message}")),
        );
      }
    } else {
      try {
        await platform.invokeMethod("startProjection");
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("service_running", true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.started)),
        );
        setState(() {
          isProjectionRunning = true;
        });
      } on PlatformException catch (e) {
        print("❌ Failed to start projection: ${e.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to start projection: ${e.message}")),
        );
      }
    }
  }

  Future<void> _loadScreenshots() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory("${appDir.path}/KidsWatchScreenshots");

    if (!await dir.exists()) {
      print("[KidsWatch] ❌ Folder does not exist: ${dir.path}");
      setState(() {
        screenshots = [];
      });
      return;
    }

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith(".png"))
        .toList();

    files.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    print("[KidsWatch] ✅ Found ${files.length} screenshots");
    for (final f in files) {
      print("→ ${f.path}");
    }

    setState(() {
      screenshots = files;
    });
  }

  Future<void> _deleteScreenshots() async {
    final loc = AppLocalizations.of(context);
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory("${appDir.path}/KidsWatchScreenshots");

    if (!await dir.exists()) {
      print("[KidsWatch] ❌ Folder does not exist: ${dir.path}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.folderDoesNotExist)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.deleteTitle),
        content: Text(loc.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    for (var file in dir.listSync()) {
      if (file is File && file.path.toLowerCase().endsWith(".png")) {
        await file.delete();
        print("[KidsWatch] 🗑️ Deleted file: ${file.path}");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.deleted)),
    );

    await _loadScreenshots();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Kids Watch"),
        actions: [
          IconButton(
            icon: Icon(isProjectionRunning ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleProjection,
            tooltip: isProjectionRunning ? loc.pause : loc.play,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadScreenshots,
            tooltip: loc.refresh,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteScreenshots,
            tooltip: loc.delete,
          ),
        ],
      ),
      body: screenshots.isEmpty
          ? Center(child: Text(loc.noScreenshots))
          : ListView.builder(
        itemCount: screenshots.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.file(screenshots[index]),
          );
        },
      ),
    );
  }
}

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _localizedValues = {
    'en': {
      'play': 'Start Projection',
      'pause': 'Stop Projection',
      'refresh': 'Refresh',
      'delete': 'Delete all',
      'deleteTitle': 'Delete All Screenshots',
      'deleteConfirm': 'Are you sure you want to delete all screenshots?',
      'cancel': 'Cancel',
      'deleted': 'All screenshots deleted!',
      'folderDoesNotExist': 'Screenshots folder does not exist.',
      'started': 'Projection started.',
      'stopped': 'Projection stopped.',
      'noScreenshots': 'No screenshots found.',
    },
    'ar': {
      'play': 'بدء العرض',
      'pause': 'إيقاف العرض',
      'refresh': 'تحديث',
      'delete': 'حذف الكل',
      'deleteTitle': 'حذف جميع لقطات الشاشة',
      'deleteConfirm': 'هل أنت متأكد أنك تريد حذف جميع لقطات الشاشة؟',
      'cancel': 'إلغاء',
      'deleted': 'تم حذف جميع لقطات الشاشة!',
      'folderDoesNotExist': 'مجلد لقطات الشاشة غير موجود.',
      'started': 'تم بدء العرض.',
      'stopped': 'تم إيقاف العرض.',
      'noScreenshots': 'لا توجد لقطات شاشة.',
    },
  };

  String get play => _localizedValues[locale.languageCode]!['play']!;
  String get pause => _localizedValues[locale.languageCode]!['pause']!;
  String get refresh => _localizedValues[locale.languageCode]!['refresh']!;
  String get delete => _localizedValues[locale.languageCode]!['delete']!;
  String get deleteTitle =>
      _localizedValues[locale.languageCode]!['deleteTitle']!;
  String get deleteConfirm =>
      _localizedValues[locale.languageCode]!['deleteConfirm']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get deleted => _localizedValues[locale.languageCode]!['deleted']!;
  String get folderDoesNotExist =>
      _localizedValues[locale.languageCode]!['folderDoesNotExist']!;
  String get started => _localizedValues[locale.languageCode]!['started']!;
  String get stopped => _localizedValues[locale.languageCode]!['stopped']!;
  String get noScreenshots =>
      _localizedValues[locale.languageCode]!['noScreenshots']!;
}

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
