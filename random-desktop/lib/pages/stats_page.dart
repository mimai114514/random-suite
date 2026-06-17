import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';

/// 数据统计页面
class StatsPage extends StatefulWidget {
  final DatabaseService db;
  const StatsPage({super.key, required this.db});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _isLoading = true;
  Map<String, int> _modeCounts = {};
  List<Map<String, dynamic>> _groupCounts = [];
  List<Map<String, dynamic>> _dailyCounts = [];
  int _totalLogs = 0;

  // 项统计
  List<Map<String, dynamic>> _groups = [];
  int? _selectedGroupId;
  List<Map<String, dynamic>> _itemTotalCounts = [];
  List<Map<String, dynamic>> _itemPeriodCounts = [];
  List<Map<String, dynamic>> _itemLastDrawn = [];
  int _periodDays = 7; // 7 or 30

  // 展开状态
  bool _expandTotal = false;
  bool _expandPeriod = false;
  bool _expandLastDrawn = false;

  static const int _defaultShow = 10;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final modeCounts = await widget.db.getModeCounts();
    final groupCounts = await widget.db.getGroupDrawCounts();
    final dailyCounts = await widget.db.getDailyDrawCounts(14);
    final totalLogs = await widget.db.getLogCount();
    final groups = await widget.db.getGroups();

    setState(() {
      _modeCounts = modeCounts;
      _groupCounts = groupCounts;
      _dailyCounts = dailyCounts;
      _totalLogs = totalLogs;
      _groups = groups;
      _isLoading = false;
      // 默认选中第一个列表
      if (_selectedGroupId == null && groups.isNotEmpty) {
        _selectedGroupId = groups.first['id'] as int;
      }
    });

    if (_selectedGroupId != null) {
      _loadItemStats();
    }
  }

  Future<void> _loadItemStats() async {
    if (_selectedGroupId == null) return;
    final totalCounts = await widget.db.getItemDrawCounts(_selectedGroupId!);
    final periodCounts = await widget.db.getItemDrawCountsByPeriod(
      _selectedGroupId!,
      _periodDays,
    );
    final lastDrawn = await widget.db.getItemLastDrawTime(_selectedGroupId!);
    setState(() {
      _itemTotalCounts = totalCounts;
      _itemPeriodCounts = periodCounts;
      _itemLastDrawn = lastDrawn;
      _expandTotal = false;
      _expandPeriod = false;
      _expandLastDrawn = false;
    });
  }

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
              Icon(Icons.bar_chart_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '数据统计',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 内容区
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _totalLogs == 0
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.analytics_rounded,
                        size: 64,
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '暂无统计数据，先进行一些抽取吧',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 概览卡片
                      _buildOverviewCards(colorScheme),
                      const SizedBox(height: 20),
                      // 每日趋势图
                      if (_dailyCounts.isNotEmpty) ...[
                        _buildSectionTitle(
                          '近 14 天抽取趋势',
                          Icons.show_chart_rounded,
                        ),
                        const SizedBox(height: 8),
                        _buildDailyChart(colorScheme),
                        const SizedBox(height: 20),
                      ],
                      // 各组抽取分布
                      if (_groupCounts.isNotEmpty) ...[
                        _buildSectionTitle('各列表组抽取分布', Icons.pie_chart_rounded),
                        const SizedBox(height: 8),
                        _buildGroupChart(colorScheme),
                        const SizedBox(height: 20),
                      ],
                      // 项统计
                      if (_groups.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildItemStatsSection(colorScheme),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ==================== 项统计区域 ====================

  Widget _buildItemStatsSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题 + 列表选择
        Row(
          children: [
            Icon(Icons.analytics_rounded, size: 20, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '项统计',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<int>(
                value: _selectedGroupId,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _groups.map((g) {
                  return DropdownMenuItem<int>(
                    value: g['id'] as int,
                    child: Text(
                      g['name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedGroupId = v);
                    _loadItemStats();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 板块一：总抽取次数
        _buildItemStatCard(
          colorScheme,
          title: '项总抽取次数',
          icon: Icons.bar_chart_rounded,
          items: _itemTotalCounts,
          valueKey: 'selected_count',
          valueLabel: '次',
          expanded: _expandTotal,
          onToggle: () => setState(() => _expandTotal = !_expandTotal),
        ),
        const SizedBox(height: 12),

        // 板块二：近 N 天抽取次数
        _buildPeriodStatCard(colorScheme),
        const SizedBox(height: 12),

        // 板块三：最久未被抽取
        _buildLastDrawnCard(colorScheme),
      ],
    );
  }

  /// 通用项统计卡片
  Widget _buildItemStatCard(
    ColorScheme colorScheme, {
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required String valueKey,
    required String valueLabel,
    required bool expanded,
    required VoidCallback onToggle,
    Widget? trailing,
  }) {
    final showItems = expanded ? items : items.take(_defaultShow).toList();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing],
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '暂无数据',
                    style: TextStyle(color: colorScheme.outline, fontSize: 13),
                  ),
                ),
              )
            else ...[
              ...showItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final content = item['content'] as String;
                final value = item[valueKey] as int? ?? 0;
                return _buildItemRow(
                  colorScheme,
                  index: i + 1,
                  content: content,
                  trailing: Text(
                    '$value $valueLabel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                );
              }),
              if (items.length > _defaultShow)
                Center(
                  child: TextButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(
                      expanded ? '收起' : '展开全部（共 ${items.length} 项）',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 近 N 天统计卡片（带 7/30 天切换）
  Widget _buildPeriodStatCard(ColorScheme colorScheme) {
    return _buildItemStatCard(
      colorScheme,
      title: '近 $_periodDays 天抽取次数',
      icon: Icons.date_range_rounded,
      items: _itemPeriodCounts,
      valueKey: 'period_count',
      valueLabel: '次',
      expanded: _expandPeriod,
      onToggle: () => setState(() => _expandPeriod = !_expandPeriod),
      trailing: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 7, label: Text('7 天')),
          ButtonSegment(value: 30, label: Text('30 天')),
        ],
        selected: {_periodDays},
        onSelectionChanged: (v) {
          setState(() => _periodDays = v.first);
          _loadItemStats();
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }

  /// 最久未被抽取卡片
  Widget _buildLastDrawnCard(ColorScheme colorScheme) {
    final showItems = _expandLastDrawn
        ? _itemLastDrawn
        : _itemLastDrawn.take(_defaultShow).toList();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                const Text(
                  '最久未被抽取',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_itemLastDrawn.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '暂无数据',
                    style: TextStyle(color: colorScheme.outline, fontSize: 13),
                  ),
                ),
              )
            else ...[
              ...showItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final content = item['content'] as String;
                final lastDrawn = item['last_drawn'] as String?;
                String label;
                Color labelColor;
                if (lastDrawn == null) {
                  label = '从未抽取';
                  labelColor = colorScheme.error;
                } else {
                  try {
                    final dt = DateTime.parse(lastDrawn);
                    final diff = DateTime.now().difference(dt);
                    if (diff.inDays > 0) {
                      label = '${diff.inDays} 天前';
                    } else if (diff.inHours > 0) {
                      label = '${diff.inHours} 小时前';
                    } else {
                      label = '刚刚';
                    }
                    labelColor = colorScheme.outline;
                  } catch (_) {
                    label = lastDrawn;
                    labelColor = colorScheme.outline;
                  }
                }
                return _buildItemRow(
                  colorScheme,
                  index: i + 1,
                  content: content,
                  trailing: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                );
              }),
              if (_itemLastDrawn.length > _defaultShow)
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _expandLastDrawn = !_expandLastDrawn),
                    icon: Icon(
                      _expandLastDrawn
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _expandLastDrawn
                          ? '收起'
                          : '展开全部（共 ${_itemLastDrawn.length} 项）',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 单行项展示
  Widget _buildItemRow(
    ColorScheme colorScheme, {
    required int index,
    required String content,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  // ==================== 原有统计 ====================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// 概览统计卡片
  Widget _buildOverviewCards(ColorScheme colorScheme) {
    final numCount = _modeCounts['nummode'] ?? 0;
    final listCount = _modeCounts['listmode'] ?? 0;

    return Row(
      children: [
        _buildStatCard(
          colorScheme,
          icon: Icons.casino_rounded,
          label: '总抽取次数',
          value: '$_totalLogs',
          color: colorScheme.primary,
          bgColor: colorScheme.primaryContainer,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          colorScheme,
          icon: Icons.tag_rounded,
          label: '数字模式',
          value: '$numCount',
          color: colorScheme.tertiary,
          bgColor: colorScheme.tertiaryContainer,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          colorScheme,
          icon: Icons.list_alt_rounded,
          label: '列表模式',
          value: '$listCount',
          color: colorScheme.secondary,
          bgColor: colorScheme.secondaryContainer,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: bgColor.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 每日趋势折线图
  Widget _buildDailyChart(ColorScheme colorScheme) {
    final spots = <FlSpot>[];
    final labels = <int, String>{};

    for (int i = 0; i < _dailyCounts.length; i++) {
      final count = _dailyCounts[i]['count'] as int;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
      final dateStr = _dailyCounts[i]['date'] as String;
      if (dateStr.length >= 10) {
        labels[i] = dateStr.substring(5);
      }
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (labels.containsKey(idx) &&
                          (spots.length <= 7 || idx % 2 == 0)) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx]!,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.outline,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      if (value == value.roundToDouble()) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.outline,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: colorScheme.primary,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: colorScheme.primary,
                          strokeWidth: 2,
                          strokeColor: colorScheme.surface,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 列表组分布柱状图
  Widget _buildGroupChart(ColorScheme colorScheme) {
    final data = _groupCounts.take(10).toList();
    if (data.isEmpty) return const SizedBox.shrink();

    final maxCount = data
        .map((e) => e['count'] as int)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxCount * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxCount / 4).ceilToDouble().clamp(
                  1,
                  double.infinity,
                ),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < data.length) {
                        final name = data[idx]['name'] as String;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            name.length > 6 ? '${name.substring(0, 5)}…' : name,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.outline,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      if (value == value.roundToDouble()) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.outline,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(data.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: (data[i]['count'] as int).toDouble(),
                      width: 24,
                      color: colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
