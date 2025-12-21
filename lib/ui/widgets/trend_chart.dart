import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class TrendChart extends StatefulWidget {
  const TrendChart({super.key});

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  String _mode = 'strength'; // 'weight' or 'strength'

  // Strength Data
  List<FlSpot> _benchSpots = [];
  List<FlSpot> _squatSpots = [];
  List<FlSpot> _deadliftSpots = [];

  // Weight Data
  List<FlSpot> _weightSpots = [];

  // Toggles
  bool _showBench = true;
  bool _showSquat = true;
  bool _showDeadlift = true;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // 1. Fetch Strength Data
      final strengthRes = await Supabase.instance.client
          .from('strength_progress')
          .select('date, exercise, weight_kg')
          .eq('user_id', uid)
          .order('date', ascending: true);

      // 2. Fetch Body Weight Data
      final weightRes = await Supabase.instance.client
          .from('body_metrics')
          .select('date, weight_kg')
          .eq('user_id', uid)
          .order('date', ascending: true)
          .limit(30);

      if (mounted) {
        setState(() {
          _processStrengthData(strengthRes as List);
          _processWeightData(weightRes as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _processWeightData(List data) {
    final List<FlSpot> spots = [];
    if (data.isNotEmpty) {
      DateTime? firstDate;
      try {
        firstDate = DateTime.parse(data.first['date']);
      } catch (_) {}

      if (firstDate != null) {
        for (var record in data) {
          try {
            final w = (record['weight_kg'] as num).toDouble();
            final d = DateTime.parse(record['date']);
            final diff = d.difference(firstDate).inDays.toDouble();
            spots.add(FlSpot(diff, w));
          } catch (_) {}
        }
      }
    }
    _weightSpots = spots;
  }

  void _processStrengthData(List data) {
    final Map<String, List<FlSpot>> spotsMap = {
      'bench': [],
      'squat': [],
      'deadlift': []
    };

    if (data.isNotEmpty) {
      DateTime? firstDate;
      try {
        firstDate = DateTime.parse(data.first['date']);
      } catch (_) {}

      if (firstDate != null) {
        for (var record in data) {
          try {
            final w = (record['weight_kg'] as num).toDouble();
            String type = (record['exercise'] as String).toLowerCase();

            // Normalize names
            if (type.contains('bench') || type.contains('卧推'))
              type = 'bench';
            else if (type.contains('squat') || type.contains('深蹲'))
              type = 'squat';
            else if (type.contains('dead') || type.contains('硬拉'))
              type = 'deadlift';

            if (spotsMap.containsKey(type)) {
              final d = DateTime.parse(record['date']);
              final diff = d.difference(firstDate).inDays.toDouble();
              spotsMap[type]!.add(FlSpot(diff, w));
            }
          } catch (_) {}
        }
      }
    }

    _benchSpots = spotsMap['bench']!;
    _squatSpots = spotsMap['squat']!;
    _deadliftSpots = spotsMap['deadlift']!;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 240, child: Center(child: CircularProgressIndicator()));
    }

    List<LineChartBarData> lineBars = [];
    double minY = 9999;
    double maxY = 0;
    double maxX = 0; // Track max X for axis range
    bool isEmpty = true;

    if (_mode == 'strength') {
      final allSpots = [
        if (_showBench) ..._benchSpots,
        if (_showSquat) ..._squatSpots,
        if (_showDeadlift) ..._deadliftSpots,
      ];
      if (allSpots.isNotEmpty) isEmpty = false;

      for (var s in allSpots) {
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
        if (s.x > maxX) maxX = s.x;
      }

      if (_showBench && _benchSpots.isNotEmpty)
        lineBars.add(_buildLine(_benchSpots, Colors.blue));
      if (_showSquat && _squatSpots.isNotEmpty)
        lineBars.add(_buildLine(_squatSpots, Colors.orange));
      if (_showDeadlift && _deadliftSpots.isNotEmpty)
        lineBars.add(_buildLine(_deadliftSpots, Colors.red));
    } else {
      if (_weightSpots.isNotEmpty) {
        isEmpty = false;
        for (var s in _weightSpots) {
          if (s.y < minY) minY = s.y;
          if (s.y > maxY) maxY = s.y;
          if (s.x > maxX) maxX = s.x;
        }
        lineBars.add(_buildLine(_weightSpots, AppTheme.primaryColor));
      }
    }

    if (isEmpty) {
      minY = 0;
      maxY = 100;
      maxX = 7;
    } else {
      minY = (minY - 5).floorToDouble();
      if (minY < 0) minY = 0;
      maxY = (maxY + 5).ceilToDouble();
      if (maxX < 7) maxX = 7; // Minimum 1 week width
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding:
              const EdgeInsets.only(right: 18, left: 12, top: 16, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeBtn('体重', 'weight'),
                          _buildModeBtn('力量', 'strength'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _fetchData,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_mode == 'strength')
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('卧推', Colors.blue, _showBench,
                          (v) => setState(() => _showBench = v)),
                      const SizedBox(width: 8),
                      _buildFilterChip('深蹲', Colors.orange, _showSquat,
                          (v) => setState(() => _showSquat = v)),
                      const SizedBox(width: 8),
                      _buildFilterChip('硬拉', Colors.red, _showDeadlift,
                          (v) => setState(() => _showDeadlift = v)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              isEmpty
                  ? Expanded(
                      child: Center(
                        child: Text(
                          _mode == 'weight' ? "暂无体重记录" : "暂无力量记录",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : Expanded(
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 20,
                            getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.withOpacity(0.1),
                                strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles:
                                        false)), // Hide date labels for simplicity
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          minY: minY,
                          maxY: maxY,
                          minX: 0,
                          maxX: maxX,
                          lineBarsData: lineBars,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeBtn(String label, String modeKey) {
    final bool isSelected = _mode == modeKey;
    return InkWell(
      onTap: () => setState(() => _mode = modeKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 2)
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
    );
  }

  Widget _buildFilterChip(
      String label, Color color, bool selected, ValueChanged<bool> onSelected) {
    return FilterChip(
      label: Text(label,
          style:
              TextStyle(color: selected ? Colors.white : color, fontSize: 12)),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.white,
      selectedColor: color,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color)),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}
