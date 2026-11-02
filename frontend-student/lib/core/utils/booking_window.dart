class BookingWindow {
  static const _indiaOffset = Duration(hours: 5, minutes: 30);

  static DateTime indiaNow({DateTime? now}) {
    return (now ?? DateTime.now()).toUtc().add(_indiaOffset);
  }

  static DateTime targetBookingDate({DateTime? now}) {
    final indiaTime = indiaNow(now: now);
    final cutoff = DateTime.utc(
      indiaTime.year,
      indiaTime.month,
      indiaTime.day,
      13,
      45,
    );
    final targetDate = indiaTime.isBefore(cutoff)
        ? indiaTime
        : indiaTime.add(const Duration(days: 1));

    return DateTime(targetDate.year, targetDate.month, targetDate.day);
  }

  static DateTime today({DateTime? now}) {
    final indiaTime = indiaNow(now: now);
    return DateTime(indiaTime.year, indiaTime.month, indiaTime.day);
  }
}
