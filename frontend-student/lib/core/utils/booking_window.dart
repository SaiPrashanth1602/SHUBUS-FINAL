class BookingWindow {
  static const _indiaOffset = Duration(hours: 5, minutes: 30);

  /// Bookings for a date open at 7:30 PM the previous day.
  static const int openHour = 19;
  static const int openMinute = 30;

  /// Bookings and cancellations close at 1:45 PM on the operation day.
  static const int closeHour = 13;
  static const int closeMinute = 45;

  static DateTime indiaNow({DateTime? now}) {
    return (now ?? DateTime.now()).toUtc().add(_indiaOffset);
  }

  static DateTime targetBookingDate({DateTime? now}) {
    final indiaTime = indiaNow(now: now);
    final cutoff = DateTime.utc(
      indiaTime.year,
      indiaTime.month,
      indiaTime.day,
      closeHour,
      closeMinute,
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

  /// Opening moment (India time, flagged UTC) for a booking date: 7:30 PM the day before.
  static DateTime opensAt(DateTime bookingDate) {
    return DateTime.utc(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      openHour,
      openMinute,
    ).subtract(const Duration(days: 1));
  }

  /// Closing moment (India time, flagged UTC) for a booking date: 1:45 PM that day.
  static DateTime closesAt(DateTime bookingDate) {
    return DateTime.utc(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      closeHour,
      closeMinute,
    );
  }

  static bool isBeforeOpening(DateTime bookingDate, {DateTime? now}) {
    return indiaNow(now: now).isBefore(opensAt(bookingDate));
  }

  static bool isAfterCutoff(DateTime bookingDate, {DateTime? now}) {
    return !indiaNow(now: now).isBefore(closesAt(bookingDate));
  }

  /// True only between 7:30 PM the previous day and 1:45 PM on the day.
  /// This is for display only; the backend is the final authority.
  static bool isOpen(DateTime bookingDate, {DateTime? now}) {
    return !isBeforeOpening(bookingDate, now: now) &&
        !isAfterCutoff(bookingDate, now: now);
  }

  /// Cancellation uses the same 1:45 PM cutoff as booking.
  static bool canCancel(DateTime bookingDate, {DateTime? now}) {
    return !isAfterCutoff(bookingDate, now: now);
  }

  /// Short message for the closed state, or null when booking is open.
  static String? closedMessage(DateTime bookingDate, {DateTime? now}) {
    if (isBeforeOpening(bookingDate, now: now)) {
      return 'Booking opens at 7:30 PM';
    }
    if (isAfterCutoff(bookingDate, now: now)) {
      return 'Booking closed at 1:45 PM';
    }
    return null;
  }
}