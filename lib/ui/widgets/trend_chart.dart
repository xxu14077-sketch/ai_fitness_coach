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
  List<FlSpot> _spots = [];
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

      // Fetch last 7 records
      final res = await Supabase.instance.client
          .from('body_metrics')
          .select('date, weight_kg')
          .eq('user_id', uid)
          .order('date', ascending: false)
          .limit(7);

      final data = (res as List).reversed.toList(); // Oldest first

      if (data.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final List<FlSpot> spots = [];
      for (int i = 0; i < data.length; i++) {
        final w = data[i]['weight_kg'] as num;
        spots.add(FlSpot(i.toDouble(), w.toDouble()));
      }

      if (mounted) {
        setState(() {
          _spots = spots;
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
          height: 200, child: Center(child: CircularProgressIndicator()));
    }

    // If no data, show empty state or mock with "Demo" label
    if (_spots.isEmpty) {
      return AspectRatio(
          aspectRatio: 1.70,
          child: Container(
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
                  const Icon(Icons.show_chart, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text("暂无体重记录", style: TextStyle(color: Colors.grey)),
                  TextButton(onPressed: _fetchData, child: const Text("刷新"))
                ],
              ))));
    }

    // Determine Y axis range
    double minY = _spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = _spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    minY = (minY - 2).floorToDouble();
    maxY = (maxY + 2).ceilToDouble();

    return AspectRatio(
      aspectRatio: 1.70,
      child: Container(
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
            top: 24,
            bottom: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      '体重趋势 (kg)',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    onPressed: _fetchData,
                  )
                ],
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
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
                    borderData: FlBorderData(
                      show: false,
                    ),
                    minX: 0,
                    maxX: (_spots.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _spots,
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            Colors.blueAccent,
                          ],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.3),
                              Colors.blueAccent.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
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
}
