import 'package:flutter/material.dart';

class ActivityDetailsScreen extends StatelessWidget {
  final String activityId;

  const ActivityDetailsScreen({super.key, required this.activityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Details')),
      body: Center(
        child: Text('Activity ID: $activityId'),
      ),
    );
  }
}
