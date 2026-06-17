import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows 平台使用 ffi 初始化 sqflite
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(const RandomDesktopApp());
}
