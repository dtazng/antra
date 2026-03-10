import 'package:flutter/material.dart';

import 'package:antra/screens/review/monthly_review_screen.dart';
import 'package:antra/screens/review/weekly_review_screen.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.view_week_outlined),
            title: const Text('Weekly Review'),
            subtitle: const Text('Review open tasks and events for this week'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WeeklyReviewScreen(),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Monthly Reflection'),
            subtitle: const Text(
                'Reflect on top interactions and events for this month'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MonthlyReflectionScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
