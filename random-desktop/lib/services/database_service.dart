import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static const String _dbName = 'random.db';
  late Database _db;

  Future<void> initialize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, 'dev', 'Random', _dbName);

    // Ensure directory exists
    await Directory(dirname(path)).create(recursive: true);

    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS lists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0,
            selected_count INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS list_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            list_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0,
            selected_count INTEGER DEFAULT 0,
            FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            mode TEXT NOT NULL,
            list_id INTEGER,
            item_id INTEGER,
            result_number INTEGER,
            FOREIGN KEY (list_id) REFERENCES lists(id),
            FOREIGN KEY (item_id) REFERENCES list_items(id)
          )
        ''');
      },
    );
  }

  // ==================== List Operations ====================

  Future<List<Map<String, dynamic>>> getGroups() async {
    return await _db.query(
      'lists',
      orderBy: 'sort_order, id',
    ); // Renamed table, kept method name for compatibility
  }

  Future<int> addGroup(String name) async {
    final result = await _db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), 0) + 1 as next_order FROM lists',
    );
    final nextOrder = result.first['next_order'] as int;

    return await _db.insert('lists', {'name': name, 'sort_order': nextOrder});
  }

  Future<void> updateGroup(int id, String name) async {
    await _db.update('lists', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteGroup(int id) async {
    await _db.delete('lists', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Item Operations ====================

  Future<List<Map<String, dynamic>>> getItems(int listId) async {
    return await _db.query(
      'list_items',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'sort_order, id',
    );
  }

  Future<int> addItem(int listId, String content) async {
    final result = await _db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), 0) + 1 as next_order FROM list_items WHERE list_id = ?',
      [listId],
    );
    final nextOrder = result.first['next_order'] as int;

    return await _db.insert('list_items', {
      'list_id': listId,
      'content': content,
      'sort_order': nextOrder,
    });
  }

  Future<void> addItems(int listId, List<String> contents) async {
    final result = await _db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), 0) + 1 as next_order FROM list_items WHERE list_id = ?',
      [listId],
    );
    int nextOrder = result.first['next_order'] as int;

    final batch = _db.batch();
    for (final content in contents) {
      batch.insert('list_items', {
        'list_id': listId,
        'content': content,
        'sort_order': nextOrder++,
      });
    }
    await batch.commit();
  }

  Future<void> updateItem(int id, String content) async {
    await _db.update(
      'list_items',
      {'content': content},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(int id) async {
    await _db.delete('list_items', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Log Operations ====================

  Future<List<Map<String, dynamic>>> getLogs({
    int limit = 50,
    int offset = 0,
    String? modeFilter,
    String? searchQuery,
  }) async {
    final where = <String>[];
    final args = <dynamic>[];
    if (modeFilter != null) {
      where.add('l.mode = ?');
      args.add(modeFilter);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(i.content LIKE ? OR CAST(l.result_number AS TEXT) LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    args.addAll([limit, offset]);
    return await _db.rawQuery('''
      SELECT 
        l.id, l.timestamp, l.mode, l.result_number,
        l.list_id, l.item_id,
        g.name as group_name,
        i.content as item_content
      FROM logs l
      LEFT JOIN lists g ON l.list_id = g.id
      LEFT JOIN list_items i ON l.item_id = i.id
      $whereClause
      ORDER BY l.id DESC
      LIMIT ? OFFSET ?
    ''', args);
  }

  Future<int> getLogCount({String? modeFilter, String? searchQuery}) async {
    final where = <String>[];
    final args = <dynamic>[];
    if (modeFilter != null) {
      where.add('l.mode = ?');
      args.add(modeFilter);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(i.content LIKE ? OR CAST(l.result_number AS TEXT) LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final result = await _db.rawQuery('''
      SELECT COUNT(*) as count
      FROM logs l
      LEFT JOIN lists g ON l.list_id = g.id
      LEFT JOIN list_items i ON l.item_id = i.id
      $whereClause
    ''', args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> addLog({
    String mode = 'listmode',
    int? listId,
    int? itemId,
    int? resultNumber,
  }) async {
    await _db.transaction((txn) async {
      await txn.insert('logs', {
        'timestamp': DateTime.now().toIso8601String(),
        'mode': mode,
        'list_id': listId,
        'item_id': itemId,
        'result_number': resultNumber,
      });

      if (mode == 'listmode' && listId != null && itemId != null) {
        await txn.rawUpdate(
          'UPDATE lists SET selected_count = selected_count + 1 WHERE id = ?',
          [listId],
        );
        await txn.rawUpdate(
          'UPDATE list_items SET selected_count = selected_count + 1 WHERE id = ?',
          [itemId],
        );
      }
    });
  }

  Future<void> clearLogs() async {
    // Ideally we might want to reset counts too, or not?
    // Usually clear logs means clear history, but counts might be persistent stats.
    // User didn't specify, so I will just clear logs table, and counts remain.
    await _db.delete('logs');
  }

  Future<void> deleteLog(int id) async {
    await _db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Stats Operations ====================

  Future<Map<String, int>> getModeCounts() async {
    final result = await _db.rawQuery('''
      SELECT mode, COUNT(*) as count 
      FROM logs 
      GROUP BY mode
    ''');

    final Map<String, int> counts = {};
    for (final row in result) {
      counts[row['mode'] as String] = row['count'] as int;
    }
    return counts;
  }

  Future<List<Map<String, dynamic>>> getGroupDrawCounts() async {
    // Can now use the counter directly or count logs. Counting logs is more robust if logs are deleted but counts persist?
    // Or if counts are intended to be a cache. The user said "add selected_count... increase it...".
    // This implies we should use this new column for display if possible, or maybe it's for external tools?
    // "再在desktop中的对应位置增加显示" -> Display it.
    // For this stats query, counting logs is still correct for "Draw Counts" history.
    // But for "Show in UI", I should use the column in ListPage.

    return await _db.rawQuery('''
      SELECT g.name, COUNT(l.id) as count
      FROM logs l
      JOIN lists g ON l.list_id = g.id
      WHERE l.mode = 'listmode'
      GROUP BY g.id
      ORDER BY count DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getDailyDrawCounts(int days) async {
    return await _db.rawQuery('''
      SELECT substr(timestamp, 1, 10) as date, COUNT(*) as count
      FROM logs
      WHERE date(timestamp) >= date('now', '-$days days')
      GROUP BY date
      ORDER BY date ASC
    ''');
  }

  // ==================== Item Stats ====================

  /// 获取指定列表中每个项的总抽取次数，按次数降序
  Future<List<Map<String, dynamic>>> getItemDrawCounts(int listId) async {
    return await _db.query(
      'list_items',
      columns: ['id', 'content', 'selected_count'],
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'selected_count DESC',
    );
  }

  /// 获取指定列表中每个项在最近 N 天内的抽取次数
  Future<List<Map<String, dynamic>>> getItemDrawCountsByPeriod(
    int listId,
    int days,
  ) async {
    return await _db.rawQuery(
      '''
      SELECT 
        i.id, i.content,
        COUNT(l.id) as period_count
      FROM list_items i
      LEFT JOIN logs l ON l.item_id = i.id
        AND l.mode = 'listmode'
        AND date(l.timestamp) >= date('now', '-$days days')
      WHERE i.list_id = ?
      GROUP BY i.id
      ORDER BY period_count DESC
    ''',
      [listId],
    );
  }

  /// 获取指定列表中每个项最后被抽取的时间，按时间升序（最久未抽取的在前）
  Future<List<Map<String, dynamic>>> getItemLastDrawTime(int listId) async {
    return await _db.rawQuery(
      '''
      SELECT
        i.id, i.content,
        MAX(l.timestamp) as last_drawn
      FROM list_items i
      LEFT JOIN logs l ON l.item_id = i.id AND l.mode = 'listmode'
      WHERE i.list_id = ?
      GROUP BY i.id
      ORDER BY last_drawn IS NOT NULL, last_drawn ASC
    ''',
      [listId],
    );
  }
}
