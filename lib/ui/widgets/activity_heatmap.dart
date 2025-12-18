import 'package:flutter/material.dart';
import '../theme.dart';

class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock activity data: 0 = none, 1 = light, 2 = medium, 3 = heavy
    // Last 12 weeks (approx 84 days)
    final List<int> activityLevels = List.generate(84, (index) {
      // Simulate some random activity
      if (index % 7 == 0) return 3; // Mondays are heavy
      if (index % 3 == 0) return 2; // Every 3 days medium
      if (index % 5 == 0) return 0; // Rest days
      return 1; // Light days
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '训练活跃度',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
              ),
              Text(
                '连续 5 天',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120, // Fixed height for the grid
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true, // Show newest on the right
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, // 7 days a week (rows)
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount: activityLevels.length,
              itemBuilder: (context, index) {
                final level = activityLevels[index];
                return Container(
                  decoration: BoxDecoration(
                    color: _getColorForLevel(level),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less ', style: TextStyle(fontSize: 10, color: Colors.grey)),
              _buildLegendBox(0),
              const SizedBox(width: 2),
              _buildLegendBox(1),
              const SizedBox(width: 2),
              _buildLegendBox(2),
              const SizedBox(width: 2),
              _buildLegendBox(3),
              const Text(' More', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBox(int level) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _getColorForLevel(level),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _getColorForLevel(int level) {
    switch (level) {
      case 0:
        return Colors.grey.shade200;
      case 1:
        return AppTheme.primaryColor.withOpacity(0.3);
      case 2:
        return AppTheme.primaryColor.withOpacity(0.6);
      case 3:
        return AppTheme.primaryColor;
      default:
        return Colors.grey.shade200;
    }
  }
}
