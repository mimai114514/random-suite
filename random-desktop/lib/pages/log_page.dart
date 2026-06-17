import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

/// 抽取日志页面
class LogPage extends StatefulWidget {
  final DatabaseService db;
  const LogPage({super.key, required this.db});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  int _totalCount = 0;
  static const int _pageSize = 50;
  int _currentPage = 0;

  // 筛选与搜索
  String? _modeFilter; // null = 全部, 'nummode', 'listmode'
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _currentPage = 0;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final query = _searchController.text.trim();
    final count = await widget.db.getLogCount(
      modeFilter: _modeFilter,
      searchQuery: query.isEmpty ? null : query,
    );
    final logs = await widget.db.getLogs(
      limit: _pageSize,
      offset: _currentPage * _pageSize,
      modeFilter: _modeFilter,
      searchQuery: query.isEmpty ? null : query,
    );
    setState(() {
      _totalCount = count;
      _logs = logs;
      _isLoading = false;
    });
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '未知时间';
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return timestamp;
    }
  }

  String _formatResult(Map<String, dynamic> log) {
    final mode = log['mode'] as String;
    if (mode == 'nummode') {
      return '${log['result_number'] ?? '?'}';
    } else {
      final content = log['item_content'] as String?;
      return content ?? '(已删除)';
    }
  }

  String _formatMode(String mode) {
    return mode == 'nummode' ? '数字模式' : '列表模式';
  }

  IconData _modeIcon(String mode) {
    return mode == 'nummode' ? Icons.tag_rounded : Icons.list_alt_rounded;
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 9999);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 顶部标题栏
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '抽取日志',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
                  '共 $_totalCount 条',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              // 搜索框
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isSearching ? 200 : 0,
                height: 40,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '搜索结果...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
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
              // 模式筛选
              PopupMenuButton<String?>(
                tooltip: '筛选模式',
                icon: Badge(
                  isLabelVisible: _modeFilter != null,
                  child: const Icon(Icons.filter_list_rounded),
                ),
                onSelected: (value) {
                  setState(() {
                    _modeFilter = value;
                    _currentPage = 0;
                  });
                  _loadLogs();
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String?>(
                    value: null,
                    child: ListTile(
                      leading: Icon(
                        Icons.all_inclusive_rounded,
                        color: _modeFilter == null ? colorScheme.primary : null,
                      ),
                      title: Text(
                        '全部',
                        style: _modeFilter == null
                            ? TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              )
                            : null,
                      ),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem<String?>(
                    value: 'nummode',
                    child: ListTile(
                      leading: Icon(
                        Icons.tag_rounded,
                        color: _modeFilter == 'nummode'
                            ? colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        '数字模式',
                        style: _modeFilter == 'nummode'
                            ? TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              )
                            : null,
                      ),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem<String?>(
                    value: 'listmode',
                    child: ListTile(
                      leading: Icon(
                        Icons.list_alt_rounded,
                        color: _modeFilter == 'listmode'
                            ? colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        '列表模式',
                        style: _modeFilter == 'listmode'
                            ? TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              )
                            : null,
                      ),
                      dense: true,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 日志列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _modeFilter != null || _searchController.text.isNotEmpty
                            ? '没有匹配的日志记录'
                            : '暂无日志记录',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (ctx, i) {
                    final log = _logs[i];
                    final mode = log['mode'] as String;
                    final groupName = log['group_name'] as String?;

                    return Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      margin: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: mode == 'nummode'
                              ? colorScheme.tertiaryContainer
                              : colorScheme.primaryContainer,
                          child: Icon(
                            _modeIcon(mode),
                            size: 20,
                            color: mode == 'nummode'
                                ? colorScheme.onTertiaryContainer
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          _formatResult(log),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '${_formatMode(mode)}'
                          '${groupName != null ? ' · $groupName' : ''}'
                          ' · ${_formatTimestamp(log['timestamp'] as String?)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // 分页栏
        if (_totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 0
                      ? () {
                          _currentPage--;
                          _loadLogs();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 8),
                Text(
                  '第 ${_currentPage + 1} / $_totalPages 页',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _currentPage < _totalPages - 1
                      ? () {
                          _currentPage++;
                          _loadLogs();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
