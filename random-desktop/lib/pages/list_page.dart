import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// 列表管理页面 — 左侧列表组 + 右侧项列表
class ListPage extends StatefulWidget {
  final DatabaseService db;
  const ListPage({super.key, required this.db});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _items = []; // Displayed items
  List<Map<String, dynamic>> _rawItems = []; // All items for current group
  int? _selectedGroupId;
  String? _selectedGroupName;
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // 排序
  String _sortField = 'order'; // 'order' or 'selected_count'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _searchController.addListener(_updateFilteredItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groups = await widget.db.getGroups();
    setState(() {
      _groups = groups;
      _isLoading = false;
      // 如果之前选中的组被删除了，清空选择
      if (_selectedGroupId != null &&
          !groups.any((g) => g['id'] == _selectedGroupId)) {
        _selectedGroupId = null;
        _selectedGroupName = null;
        _items = [];
      }
      // 默认选中第一个
      if (_selectedGroupId == null && _groups.isNotEmpty) {
        _selectedGroupId = _groups.first['id'] as int;
        _selectedGroupName = _groups.first['name'] as String;
      }
    });

    if (_selectedGroupId != null) {
      _loadItems(_selectedGroupId!);
    }
  }

  Future<void> _loadItems(int groupId) async {
    final items = await widget.db.getItems(groupId);
    setState(() {
      _rawItems = items;
      _updateFilteredItems();
    });
  }

  void _updateFilteredItems() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      List<Map<String, dynamic>> result;
      if (query.isEmpty) {
        result = List.from(_rawItems);
      } else {
        result = _rawItems.where((item) {
          final content = (item['content'] as String).toLowerCase();
          return content.contains(query);
        }).toList();
      }
      // 排序
      if (_sortField == 'selected_count') {
        result.sort((a, b) {
          final ca = (a['selected_count'] as int?) ?? 0;
          final cb = (b['selected_count'] as int?) ?? 0;
          return _sortAscending ? ca.compareTo(cb) : cb.compareTo(ca);
        });
      } else {
        // 按原序号（rawItems 下标）
        if (!_sortAscending) {
          result = result.reversed.toList();
        }
      }
      _items = result;
    });
  }

  void _selectGroup(int id, String name) {
    setState(() {
      _selectedGroupId = id;
      _selectedGroupName = name;
    });
    _loadItems(id);
  }

  // ==================== 列表组操作 ====================

  Future<void> _showAddGroupDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.create_new_folder_rounded),
            const SizedBox(width: 8),
            const Text('新建列表'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '列表名',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await widget.db.addGroup(result.trim());
      await _loadGroups();
    }
  }

  Future<void> _showRenameGroupDialog(int id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.edit_rounded),
        title: const Text('重命名列表'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '组名',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await widget.db.updateGroup(id, result.trim());
      if (_selectedGroupId == id) {
        _selectedGroupName = result.trim();
      }
      await _loadGroups();
    }
  }

  Future<void> _deleteGroup(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
        title: const Text('删除列表'),
        content: Text('确定要删除「$name」及其所有项吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.db.deleteGroup(id);
      await _loadGroups();
    }
  }

  // ==================== 列表项操作 ====================

  Future<void> _showAddItemDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_circle),
            const SizedBox(width: 8),
            const Text('添加项'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(
            labelText: '内容（每行一项，支持批量添加）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      final lines = result
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length == 1) {
        await widget.db.addItem(_selectedGroupId!, lines.first);
      } else {
        await widget.db.addItems(_selectedGroupId!, lines);
      }
      await _loadItems(_selectedGroupId!);
    }
  }

  Future<void> _showEditItemDialog(int id, String currentContent) async {
    final controller = TextEditingController(text: currentContent);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.edit_rounded),
        title: const Text('编辑项'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '内容',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await widget.db.updateItem(id, result.trim());
      await _loadItems(_selectedGroupId!);
    }
  }

  Future<void> _deleteItem(int id) async {
    await widget.db.deleteItem(id);
    await _loadItems(_selectedGroupId!);
  }

  // ==================== 构建 UI ====================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        // 左侧：列表组
        SizedBox(
          width: 280,
          child: Column(
            children: [
              // 顶部标题栏
              // 顶部标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    Icon(Icons.menu, size: 28, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      '列表',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: _showAddGroupDialog,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: '新建列表',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 列表组列表
              Expanded(
                child: _groups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_off_rounded,
                              size: 48,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '暂无列表',
                              style: TextStyle(color: colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _groups.length,
                        itemBuilder: (ctx, i) {
                          final group = _groups[i];
                          final id = group['id'] as int;
                          final name = group['name'] as String;

                          final isSelected = id == _selectedGroupId;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: ListTile(
                              selected: isSelected,
                              selectedTileColor: colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Icon(
                                Icons.list_alt_rounded,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outline,
                              ),
                              title: Text(name),
                              onTap: () => _selectGroup(id, name),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        VerticalDivider(
          thickness: 1,
          width: 1,
          color: colorScheme.outlineVariant,
        ),
        // 右侧：列表项
        Expanded(
          child: _selectedGroupId == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 64,
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '选择一个列表来查看项',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 顶部标题栏
                    // 顶部标题栏
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedGroupName!,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_items.length} 项${_selectedGroupId != null ? ' · 已使用 ${_groups.firstWhere((g) => g['id'] == _selectedGroupId)['selected_count'] ?? 0} 次' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _isSearching ? 200 : 0,
                            height: 40,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _isSearching
                                ? TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: '搜索...',
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (_isSearching) {
                                  _isSearching = false;
                                  _searchController.clear();
                                } else {
                                  _isSearching = true;
                                }
                              });
                            },
                            icon: Icon(
                              _isSearching
                                  ? Icons.search_off_rounded
                                  : Icons.search_rounded,
                            ),
                            tooltip: _isSearching ? '关闭搜索' : '搜索',
                          ),
                          // 排序按钮
                          PopupMenuButton<String>(
                            tooltip: '排序',
                            icon: const Icon(Icons.sort_rounded),
                            onSelected: (value) {
                              setState(() {
                                if (value == 'toggle_direction') {
                                  _sortAscending = !_sortAscending;
                                } else {
                                  _sortField = value;
                                }
                              });
                              _updateFilteredItems();
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'order',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.format_list_numbered_rounded,
                                    color: _sortField == 'order'
                                        ? colorScheme.primary
                                        : null,
                                  ),
                                  title: Text(
                                    '按序号',
                                    style: _sortField == 'order'
                                        ? TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          )
                                        : null,
                                  ),
                                  dense: true,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'selected_count',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.bar_chart_rounded,
                                    color: _sortField == 'selected_count'
                                        ? colorScheme.primary
                                        : null,
                                  ),
                                  title: Text(
                                    '按抽取次数',
                                    style: _sortField == 'selected_count'
                                        ? TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          )
                                        : null,
                                  ),
                                  dense: true,
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'toggle_direction',
                                child: ListTile(
                                  leading: Icon(
                                    _sortAscending
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                  ),
                                  title: Text(
                                    _sortAscending ? '当前：升序' : '当前：降序',
                                  ),
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _showAddItemDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('添加项'),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '更多操作',
                            icon: const Icon(Icons.more_vert_rounded),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: ListTile(
                                  leading: Icon(Icons.edit_rounded),
                                  title: Text('重命名列表'),
                                  dense: true,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete_rounded,
                                    color: Colors.red,
                                  ),
                                  title: Text(
                                    '删除列表',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  dense: true,
                                ),
                              ),
                            ],
                            onSelected: (action) {
                              if (action == 'rename') {
                                _showRenameGroupDialog(
                                  _selectedGroupId!,
                                  _selectedGroupName!,
                                );
                              } else if (action == 'delete') {
                                _deleteGroup(
                                  _selectedGroupId!,
                                  _selectedGroupName!,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 项列表
                    Expanded(
                      child: _items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inbox_rounded,
                                    size: 48,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '列表为空，点击右上角添加项',
                                    style: TextStyle(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _items.length,
                              itemBuilder: (ctx, i) {
                                final item = _items[i];
                                final id = item['id'] as int;
                                final content = item['content'] as String;

                                return Card(
                                  elevation: 0,
                                  color: colorScheme.surfaceContainerLow,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 2,
                                    horizontal: 4,
                                  ),
                                  child: ListTile(
                                    title: Text(content),
                                    subtitle:
                                        (item['selected_count'] as int? ?? 0) >
                                            0
                                        ? Text(
                                            '已抽中: ${item['selected_count']}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: colorScheme.primary,
                                            ),
                                          )
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded),
                                          iconSize: 20,
                                          tooltip: '编辑',
                                          onPressed: () =>
                                              _showEditItemDialog(id, content),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_rounded,
                                          ),
                                          iconSize: 20,
                                          tooltip: '删除',
                                          color: Colors.red.shade300,
                                          onPressed: () => _deleteItem(id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
