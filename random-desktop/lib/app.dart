import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'pages/draw_page.dart';
import 'pages/list_page.dart';
import 'pages/log_page.dart';
import 'pages/stats_page.dart';
import 'pages/about_page.dart';

/// 应用根组件
class RandomDesktopApp extends StatelessWidget {
  const RandomDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Random Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.lightBlue,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.lightBlue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }
}

/// 主框架，包含 NavigationDrawer 和页面切换
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final DatabaseService _db = DatabaseService();
  bool _isDbReady = false;

  // 导航项配置
  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.shuffle_rounded, label: '抽取'),
    _NavItem(icon: Icons.list_alt_rounded, label: '列表管理'),
    _NavItem(icon: Icons.history_rounded, label: '抽取日志'),
    _NavItem(icon: Icons.bar_chart_rounded, label: '数据统计'),
    _NavItem(icon: Icons.info_rounded, label: '关于'),
  ];

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    await _db.initialize();
    setState(() => _isDbReady = true);
  }

  Future<void> _launchFloatingTool() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    
    // 1. 尝试查找打包发布后的相对路径：..\FT\Random_FloatingTool.exe
    var ftPath = p.join(exeDir, '..', 'FT', 'Random_FloatingTool.exe');
    var ftFile = File(ftPath);
    
    if (!await ftFile.exists()) {
      // 2. 尝试寻找开发调试环境下的相对路径
      final devPath1 = p.join(exeDir, '..', '..', '..', '..', '..', 'random-floating', 'Random_FloatingTool', 'bin', 'Debug', 'net8.0-windows10.0.19041.0', 'Random_FloatingTool.exe');
      final devPath2 = p.join(exeDir, '..', '..', '..', '..', '..', 'random-floating', 'Random_FloatingTool', 'bin', 'Release', 'net8.0-windows10.0.19041.0', 'publish', 'Random_FloatingTool.exe');
      
      if (await File(devPath1).exists()) {
        ftPath = devPath1;
        ftFile = File(devPath1);
      } else if (await File(devPath2).exists()) {
        ftPath = devPath2;
        ftFile = File(devPath2);
      }
    }

    if (await ftFile.exists()) {
      try {
        await Process.start('cmd', ['/c', 'start', '', ftPath]);
        exit(0);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('启动悬浮窗程序失败: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到悬浮窗程序，请先编译 Random Floating Tool')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDbReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          const minWidth = 800.0;
          final needsScroll = constraints.maxWidth < minWidth;
          Widget content = Row(
            children: [
              // 左侧 NavigationDrawer 区域 (固定宽度为 240)
              Container(
                width: 240,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    Expanded(
                      child: NavigationDrawer(
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        children: [
                          // 顶部标题区域
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.casino_rounded,
                                  size: 28,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Random Desktop',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 导航项（用 SizedBox 间隔，不能用 Padding 包裹）
                          for (int i = 0; i < _navItems.length; i++) ...[
                            if (i > 0) const SizedBox(height: 4),
                            NavigationDrawerDestination(
                              icon: Icon(_navItems[i].icon),
                              selectedIcon: Icon(_navItems[i].icon),
                              label: Text(_navItems[i].label),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _launchFloatingTool,
                          icon: const Icon(Icons.picture_in_picture_alt_rounded),
                          label: const Text('打开悬浮窗'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 竖线分隔
              VerticalDivider(
                thickness: 1,
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              // 主内容区
              Expanded(child: _buildPage()),
            ],
          );
          if (needsScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: minWidth, child: content),
            );
          }
          return content;
        },
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return DrawPage(db: _db);
      case 1:
        return ListPage(db: _db);
      case 2:
        return LogPage(db: _db);
      case 3:
        return StatsPage(db: _db);
      case 4:
        return const AboutPage();
      default:
        return DrawPage(db: _db);
    }
  }
}

/// 导航项数据模型
class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
