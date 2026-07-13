import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum VaccinationReminderStatus {
  completed,
  dueToday,
  upcoming,
  overdue,
  scheduled,
}

class VaccinationReminderLogic {
  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  static VaccinationReminderStatus statusFor(
    Map<String, dynamic> schedule, {
    DateTime? now,
    int reminderDays = 3,
  }) {
    final scheduledDate = parseDate(
      schedule['scheduledDate'] ?? schedule['dueDate'] ?? schedule['nextDue'],
    );
    final storedStatus = (schedule['status'] ?? '').toString().toLowerCase();
    final currentDate = now ?? DateTime.now();
    final today = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );

    if (storedStatus == 'completed') {
      return VaccinationReminderStatus.completed;
    }

    if (storedStatus == 'missed') {
      return VaccinationReminderStatus.overdue;
    }

    if (scheduledDate == null) {
      return VaccinationReminderStatus.scheduled;
    }

    final dueDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    final reminderWindowStart = dueDate.subtract(Duration(days: reminderDays));

    if (today.isAfter(dueDate)) {
      return VaccinationReminderStatus.overdue;
    }

    if (_isSameDay(today, dueDate)) {
      return VaccinationReminderStatus.dueToday;
    }

    if (!today.isBefore(reminderWindowStart)) {
      return VaccinationReminderStatus.upcoming;
    }

    return VaccinationReminderStatus.scheduled;
  }

  static String statusLabel(VaccinationReminderStatus status) {
    switch (status) {
      case VaccinationReminderStatus.completed:
        return 'Completed';
      case VaccinationReminderStatus.dueToday:
        return 'Due Today';
      case VaccinationReminderStatus.upcoming:
        return 'Upcoming';
      case VaccinationReminderStatus.overdue:
        return 'Overdue';
      case VaccinationReminderStatus.scheduled:
        return 'Scheduled';
    }
  }

  static String reminderSummary(
    Map<String, dynamic> schedule, {
    DateTime? now,
    int reminderDays = 3,
  }) {
    final status = statusFor(schedule, now: now, reminderDays: reminderDays);
    final scheduledDate = parseDate(
      schedule['scheduledDate'] ?? schedule['dueDate'] ?? schedule['nextDue'],
    );

    if (scheduledDate == null) {
      return statusLabel(status);
    }

    final dateText =
        '${scheduledDate.year.toString().padLeft(4, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';

    switch (status) {
      case VaccinationReminderStatus.completed:
        return 'Completed on $dateText';
      case VaccinationReminderStatus.dueToday:
        return 'Due today, $dateText';
      case VaccinationReminderStatus.upcoming:
        return 'Upcoming on $dateText';
      case VaccinationReminderStatus.overdue:
        return 'Overdue since $dateText';
      case VaccinationReminderStatus.scheduled:
        return 'Scheduled for $dateText';
    }
  }

  static Color colorFor(VaccinationReminderStatus status) {
    switch (status) {
      case VaccinationReminderStatus.completed:
        return Colors.green;
      case VaccinationReminderStatus.dueToday:
        return Colors.deepOrange;
      case VaccinationReminderStatus.upcoming:
        return Colors.amber;
      case VaccinationReminderStatus.overdue:
        return Colors.red;
      case VaccinationReminderStatus.scheduled:
        return Colors.blueGrey;
    }
  }

  static int sortPriority(VaccinationReminderStatus status) {
    switch (status) {
      case VaccinationReminderStatus.overdue:
        return 0;
      case VaccinationReminderStatus.dueToday:
        return 1;
      case VaccinationReminderStatus.upcoming:
        return 2;
      case VaccinationReminderStatus.scheduled:
        return 3;
      case VaccinationReminderStatus.completed:
        return 4;
    }
  }

  static bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static int defaultDoseIntervalDays(String vaccineName) {
    final normalized = vaccineName.toLowerCase();

    if (normalized.contains('influenza') || normalized.contains('flu')) {
      return 365;
    }

    if (normalized.contains('hpv') || normalized.contains('covid')) {
      return 180;
    }

    if (normalized.contains('hepatitis b') ||
        normalized.contains('mmr') ||
        normalized.contains('polio') ||
        normalized.contains('dtap')) {
      return 28;
    }

    if (normalized.contains('varicella') || normalized.contains('mmr')) {
      return 90;
    }

    return 0;
  }
}
