import '../entities/trip_package.dart';

class ScheduleValidationIssue {
  final String code, message;
  final int? dayNumber;
  final String? eventId;
  final bool isWarning;
  const ScheduleValidationIssue({
    required this.code,
    required this.message,
    this.dayNumber,
    this.eventId,
    this.isWarning = false,
  });
}

class ScheduleConflictPolicy {
  const ScheduleConflictPolicy();

  static bool isValidIanaTimezone(String tz) {
    final t = tz.trim();
    if (t == 'UTC' || t == 'Etc/UTC') return true;
    final p = t.split('/');
    return p.length >= 2 && p.every((s) => s.isNotEmpty);
  }

  List<ScheduleValidationIssue> validateTrip(TripPackage trip) {
    final out = <ScheduleValidationIssue>[];
    if (!isValidIanaTimezone(trip.primaryTimezoneIana)) {
      out.add(ScheduleValidationIssue(code: 'INVALID_TRIP_TIMEZONE', message: trip.primaryTimezoneIana));
    }
    final tripEnd = DateTime.tryParse(trip.endDateIso8601);
    if (tripEnd != null) {
      for (final t in trip.travelers) {
        final exp = DateTime.tryParse(t.passportExpiryIso8601);
        if (exp != null && exp.difference(tripEnd).inDays < 180) {
          out.add(ScheduleValidationIssue(code: 'PASSPORT_EXPIRY_WARNING', message: t.fullName, isWarning: true));
        }
      }
    }
    for (final d in trip.days) {
      if (!isValidIanaTimezone(d.primaryTimezoneIana)) {
        out.add(ScheduleValidationIssue(code: 'INVALID_DAY_TIMEZONE', message: d.primaryTimezoneIana, dayNumber: d.dayNumber));
      }
      DateTime? prevEnd;
      for (final e in d.events) {
        if (!isValidIanaTimezone(e.timezoneIana)) {
          out.add(ScheduleValidationIssue(code: 'INVALID_EVENT_TIMEZONE', message: e.timezoneIana, dayNumber: d.dayNumber, eventId: e.eventId));
        }
        final s = DateTime.tryParse(e.startIso8601), end = DateTime.tryParse(e.endIso8601);
        if (s != null && end != null) {
          if (end.isBefore(s)) {
            out.add(ScheduleValidationIssue(code: 'NEGATIVE_EVENT_DURATION', message: e.title, dayNumber: d.dayNumber, eventId: e.eventId));
          }
          if (prevEnd != null && s.isBefore(prevEnd)) {
            out.add(ScheduleValidationIssue(code: 'CHRONOLOGICAL_OVERLAP', message: e.title, dayNumber: d.dayNumber, eventId: e.eventId, isWarning: true));
          }
          if (end.isAfter(prevEnd ?? s)) prevEnd = end;
        }
      }
    }
    return out;
  }
}
