import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

class TrendChart extends StatelessWidget {
  const TrendChart({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data: Last 7 days volume (tonnage or reps)
    final dataPoints = [
      const FlSpot(0, 3),
      const FlSpot(1, 1),
      const FlSpot(2, 4),
      const FlSpot(3, 2),
      const FlSpot(4, 5),
      const FlSpot(5, 3),
      const FlSpot(6, 6),
    ];

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
              const Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text(
                  '训练容量趋势',
                  style: TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const style = TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            );
                            Widget text;
                            switch (value.toInt()) {
                              case 0:
                                text = const Text('周一', style: style);
                                break;
                              case 3:
                                text = const Text('周四', style: style);
                                break;
                              case 6:
                                text = const Text('今天', style: style);
                                break;
                              default:
                                text = const Text('', style: style);
                                break;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: text,
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: false,
                    ),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: 8,
                    lineBarsData: [
                      LineChartBarData(
                        spots: dataPoints,
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            Colors.blueAccent,
                          ],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
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
