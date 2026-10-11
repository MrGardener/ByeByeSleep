const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Short day name for an ISO weekday (1 = Monday).
String dayName(int isoDay) => _dayNames[isoDay - 1];

String repeatSummary(Set<int> days) {
  if (days.isEmpty) return 'Once';
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) return 'Weekdays';
  if (days.length == 2 && days.containsAll({6, 7})) return 'Weekends';
  return (days.toList()..sort()).map(dayName).join(', ');
}
