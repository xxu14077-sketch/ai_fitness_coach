import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'package:intl/intl.dart';

class TrendChart extends StatefulWidget {
  const TrendChart({super.key});

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  // Data for each exercise
  List<FlSpot> _benchSpots = [];
  List<FlSpot> _squatSpots = [];
  List<FlSpot> _deadliftSpots = [];

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
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Fetch last 30 days records? Or just last 20 entries per type
      final res = await Supabase.instance.client
          .from('strength_progress')
          .select('date, exercise, weight_kg')
          .eq('user_id', uid)
          .order('date', ascending: true); // Get oldest first for chart

      final data = res as List;

      if (data.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Process data
      final Map<String, List<FlSpot>> spotsMap = {
        'bench': [],
        'squat': [],
        'deadlift': []
      };

      // We need to map dates to X-axis values (0, 1, 2...).
      // Simple approach: Linear index based on unique dates?
      // Or just day index? Let's use day difference from first record.

      if (data.isNotEmpty) {
        DateTime? firstDate;

        for (var record in data) {
          final dateStr = record['date'] as String;
          final date = DateTime.parse(dateStr);
          firstDate ??= date;

          final diff = date.difference(firstDate).inDays.toDouble();
          final w = (record['weight_kg'] as num).toDouble();
          final type = record['exercise'] as String;

          if (spotsMap.containsKey(type)) {
            spotsMap[type]!.add(FlSpot(diff, w));
          }
        }
      }

      if (mounted) {
        setState(() {
          _benchSpots = spotsMap['bench']!;
          _squatSpots = spotsMap['squat']!;
          _deadliftSpots = spotsMap['deadlift']!;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 240, child: Center(child: CircularProgressIndicator()));
    }

    final bool isEmpty =
        _benchSpots.isEmpty && _squatSpots.isEmpty && _deadliftSpots.isEmpty;

    if (isEmpty) {
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
              child: Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text("暂无力量记录", style: TextStyle(color: Colors.grey)),
                  TextButton(onPressed: _fetchData, child: const Text("刷新"))
                ],
              ))));
    }

    // Determine Y axis range
    double minY = 9999;
    double maxY = 0;

    final allSpots = [
      if (_showBench) ..._benchSpots,
      if (_showSquat) ..._squatSpots,
      if (_showDeadlift) ..._deadliftSpots,
    ];

    if (allSpots.isNotEmpty) {
      for (var s in allSpots) {
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
      }
      minY = (minY - 5).floorToDouble();
      if (minY < 0) minY = 0;
      maxY = (maxY + 5).ceilToDouble();
    } else {
      minY = 0;
      maxY = 100;
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
          padding: const EdgeInsets.only(
            right: 18,
            left: 12,
            top: 16,
            bottom: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '三大项容量 (Total/kg)',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
              // Filter Chips
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
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      if (_showBench)
                        LineChartBarData(
                          spots: _benchSpots,
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                        ),
                      if (_showSquat)
                        LineChartBarData(
                          spots: _squatSpots,
                          isCurved: true,
                          color: Colors.orange,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                        ),
                      if (_showDeadlift)
                        LineChartBarData(
                          spots: _deadliftSpots,
                          isCurved: true,
                          color: Colors.red,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        side: BorderSide(color: color),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}
