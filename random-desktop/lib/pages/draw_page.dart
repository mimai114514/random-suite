import 'dart:math';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// 抽取页面 — 全屏阶段式设计
class DrawPage extends StatefulWidget {
  final DatabaseService db;
  const DrawPage({super.key, required this.db});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

enum _Phase { config, reveal, summary }

class _DrawPageState extends State<DrawPage>
    with SingleTickerProviderStateMixin {
  // 阶段
  _Phase _phase = _Phase.config;

  // 模式
  String _mode = 'nummode'; // nummode / listmode

  // 数字模式参数
  final _minController = TextEditingController(text: '1');
  final _maxController = TextEditingController(text: '100');

  // 列表模式参数
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _items = [];
  int? _selectedGroupId;
  String? _selectedGroupName;

  // 抽取次数
  final _countController = TextEditingController(text: '1');

  // 结果
  final List<String> _allResults = [];
  final List<Map<String, dynamic>> _drawnItems = [];
  int _currentRound = 0;

  // 出现动画
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    _loadGroups();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _opacityAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _countController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groups = await widget.db.getGroups();
    setState(() {
      _groups = groups;
      if (groups.isNotEmpty && _selectedGroupId == null) {
        _selectedGroupId = groups.first['id'] as int;
        _selectedGroupName = groups.first['name'] as String;
      }
    });
    if (_selectedGroupId != null) {
      _loadItems(_selectedGroupId!);
    }
  }

  Future<void> _loadItems(int groupId) async {
    final items = await widget.db.getItems(groupId);
    setState(() => _items = items);
  }

  // ==================== 抽取逻辑 ====================

  void _startDraw() {
    final count = int.tryParse(_countController.text) ?? 1;
    if (count < 1) return;

    _allResults.clear();
    _drawnItems.clear();

    if (_mode == 'nummode') {
      final min = int.tryParse(_minController.text) ?? 1;
      final max = int.tryParse(_maxController.text) ?? 100;
      if (min > max) return;

      for (int i = 0; i < count; i++) {
        final result = min + _random.nextInt(max - min + 1);
        _allResults.add(result.toString());
      }
    } else {
      if (_items.isEmpty) return;

      for (int i = 0; i < count; i++) {
        final idx = _random.nextInt(_items.length);
        final item = _items[idx];
        _allResults.add(item['content'] as String);
        _drawnItems.add(item);
      }
    }

    setState(() {
      _currentRound = 0;
      _phase = _Phase.reveal;
    });
    _playRevealAnimation();
  }

  void _playRevealAnimation() {
    _animController.reset();
    _animController.forward();
  }

  void _nextResult() {
    if (_currentRound < _allResults.length - 1) {
      setState(() => _currentRound++);
      _playRevealAnimation();
    } else {
      _writeLogsAndFinish();
    }
  }

  Future<void> _writeLogsAndFinish() async {
    try {
      if (_mode == 'nummode') {
        for (final r in _allResults) {
          await widget.db.addLog(
            mode: 'nummode',
            resultNumber: int.tryParse(r),
          );
        }
      } else {
        for (final item in _drawnItems) {
          await widget.db.addLog(
            mode: 'listmode',
            listId: _selectedGroupId,
            itemId: item['id'] as int,
          );
        }
      }
    } catch (_) {}

    setState(() {
      if (_allResults.length > 1) {
        _phase = _Phase.summary;
      }
      // 单次抽取停留在 reveal，不进入汇总
    });
  }

  void _reset() {
    setState(() {
      _phase = _Phase.config;
      _allResults.clear();
      _drawnItems.clear();
      _currentRound = 0;
    });
    _loadGroups();
  }

  bool _canStart() {
    if (_mode == 'nummode') {
      final min = int.tryParse(_minController.text);
      final max = int.tryParse(_maxController.text);
      if (min == null || max == null || min > max) return false;
    } else {
      if (_items.isEmpty) return false;
    }
    final count = int.tryParse(_countController.text);
    return count != null && count >= 1;
  }

  // ==================== 构建 UI ====================

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_phase) {
        _Phase.config => _buildConfigPhase(),
        _Phase.reveal => _buildRevealPhase(),
        _Phase.summary => _buildSummaryPhase(),
      },
    );
  }

  // ---------- 阶段一：配置 ----------

  Widget _buildConfigPhase() {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      key: const ValueKey('config'),
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 100),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 模式切换
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'nummode',
                        label: Text('数字模式'),
                        icon: Icon(Icons.tag_rounded),
                      ),
                      ButtonSegment(
                        value: 'listmode',
                        label: Text('列表模式'),
                        icon: Icon(Icons.list_alt_rounded),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (v) => setState(() => _mode = v.first),
                  ),
                  const SizedBox(height: 24),

                  // 模式参数
                  if (_mode == 'nummode') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '最小值',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('~', style: TextStyle(fontSize: 24)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _maxController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '最大值',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26), // 匹配列表模式的项数显示高度
                  ] else ...[
                    if (_groups.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '暂无列表，请先在列表管理中创建',
                              style: TextStyle(color: colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: _selectedGroupId,
                        decoration: const InputDecoration(
                          labelText: '选择列表',
                          border: OutlineInputBorder(),
                        ),
                        items: _groups.map((g) {
                          return DropdownMenuItem<int>(
                            value: g['id'] as int,
                            child: Text(g['name'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedGroupId = v;
                              _selectedGroupName =
                                  _groups.firstWhere(
                                        (g) => g['id'] == v,
                                      )['name']
                                      as String;
                            });
                            _loadItems(v);
                          }
                        },
                      ),
                    if (_selectedGroupId != null && _items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '共 ${_items.length} 项',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),

                  // 抽取次数
                  TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '抽取次数',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.repeat_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 右下角开始按钮
        Positioned(
          right: 32,
          bottom: 32,
          child: FloatingActionButton.extended(
            onPressed: _canStart() ? _startDraw : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('开始抽取'),
          ),
        ),
      ],
    );
  }

  // ---------- 阶段二：逐一展示 ----------

  Widget _buildRevealPhase() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = _currentRound >= _allResults.length - 1;
    final isSingle = _allResults.length == 1;

    return Stack(
      key: ValueKey('reveal_$_currentRound'),
      children: [
        // 中心内容
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 轮次提示
              if (!isSingle)
                Text(
                  '第 ${_currentRound + 1} / ${_allResults.length} 次',
                  style: TextStyle(fontSize: 14, color: colorScheme.outline),
                ),
              if (!isSingle) const SizedBox(height: 16),

              // 结果展示（动画）
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _allResults[_currentRound],
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 模式提示
              Text(
                _mode == 'nummode'
                    ? '数字模式'
                    : '列表模式 · ${_selectedGroupName ?? ''}',
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
            ],
          ),
        ),

        // 右下角操作按钮
        Positioned(
          right: 32,
          bottom: 32,
          child: _buildRevealAction(isLast, isSingle),
        ),
      ],
    );
  }

  Widget _buildRevealAction(bool isLast, bool isSingle) {
    if (!isLast) {
      return FloatingActionButton.extended(
        onPressed: _nextResult,
        icon: const Icon(Icons.skip_next_rounded),
        label: const Text('下一个'),
      );
    }
    if (isSingle) {
      // 单次抽取：写日志后直接回到配置
      return FloatingActionButton.extended(
        onPressed: () {
          _writeLogsAndFinish();
          _reset();
        },
        icon: const Icon(Icons.check_rounded),
        label: const Text('确定'),
      );
    }
    // 多次抽取最后一个：查看汇总
    return FloatingActionButton.extended(
      onPressed: _writeLogsAndFinish,
      icon: const Icon(Icons.checklist_rounded),
      label: const Text('查看汇总'),
    );
  }

  // ---------- 阶段三：汇总 ----------

  Widget _buildSummaryPhase() {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      key: const ValueKey('summary'),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Icon(
                  Icons.checklist_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  '抽取结果',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_mode == 'nummode' ? '数字模式' : '列表模式 · ${_selectedGroupName ?? ''}'} · 共 ${_allResults.length} 次',
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
                const SizedBox(height: 24),

                // 结果列表
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _allResults.length,
                      separatorBuilder: (_, _2) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(
                            _allResults[i],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 右下角确定按钮
        Positioned(
          right: 32,
          bottom: 32,
          child: FloatingActionButton.extended(
            onPressed: _reset,
            icon: const Icon(Icons.check_rounded),
            label: const Text('确定'),
          ),
        ),
      ],
    );
  }
}
