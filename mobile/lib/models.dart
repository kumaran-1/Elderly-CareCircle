import 'package:flutter/material.dart';

enum RoleType { elder, family, caregiver, admin }

class FlowStep {
  final String title;
  final String description;
  final IconData icon;

  const FlowStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class DashboardSection {
  final String title;
  final String subtitle;
  final Color tone;

  const DashboardSection({
    required this.title,
    required this.subtitle,
    required this.tone,
  });
}
