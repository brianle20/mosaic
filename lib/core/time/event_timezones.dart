DateTime eventInstantInTimezone(DateTime instant, String timezone) {
  final utcInstant = instant.toUtc();

  return switch (timezone) {
    'UTC' || 'Etc/UTC' => utcInstant,
    'America/Los_Angeles' => utcInstant.add(
        Duration(hours: _pacificUtcOffsetHours(utcInstant)),
      ),
    _ => instant.toLocal(),
  };
}

DateTime eventWallTimeToUtc(DateTime wallTime, String timezone) {
  return switch (timezone) {
    'UTC' || 'Etc/UTC' => DateTime.utc(
        wallTime.year,
        wallTime.month,
        wallTime.day,
        wallTime.hour,
        wallTime.minute,
        wallTime.second,
        wallTime.millisecond,
        wallTime.microsecond,
      ),
    'America/Los_Angeles' => DateTime.utc(
        wallTime.year,
        wallTime.month,
        wallTime.day,
        wallTime.hour,
        wallTime.minute,
        wallTime.second,
        wallTime.millisecond,
        wallTime.microsecond,
      ).subtract(Duration(hours: _pacificWallTimeUtcOffsetHours(wallTime))),
    _ => wallTime.toUtc(),
  };
}

int _pacificUtcOffsetHours(DateTime utcInstant) {
  final year = utcInstant.year;
  final dstStart = DateTime.utc(year, 3, _secondSundayOfMarch(year), 10);
  final dstEnd = DateTime.utc(year, 11, _firstSundayOfNovember(year), 9);

  if (!utcInstant.isBefore(dstStart) && utcInstant.isBefore(dstEnd)) {
    return -7;
  }

  return -8;
}

int _pacificWallTimeUtcOffsetHours(DateTime wallTime) {
  final dstStart = DateTime(
    wallTime.year,
    3,
    _secondSundayOfMarch(wallTime.year),
    2,
  );
  final dstEnd = DateTime(
    wallTime.year,
    11,
    _firstSundayOfNovember(wallTime.year),
    2,
  );

  if (!wallTime.isBefore(dstStart) && wallTime.isBefore(dstEnd)) {
    return -7;
  }

  return -8;
}

int _secondSundayOfMarch(int year) {
  return _nthWeekdayOfMonth(
    year: year,
    month: 3,
    weekday: DateTime.sunday,
    occurrence: 2,
  );
}

int _firstSundayOfNovember(int year) {
  return _nthWeekdayOfMonth(
    year: year,
    month: 11,
    weekday: DateTime.sunday,
    occurrence: 1,
  );
}

int _nthWeekdayOfMonth({
  required int year,
  required int month,
  required int weekday,
  required int occurrence,
}) {
  final firstDay = DateTime.utc(year, month);
  final daysUntilWeekday = (weekday - firstDay.weekday) % 7;
  return 1 + daysUntilWeekday + 7 * (occurrence - 1);
}
