package com.shubus.backend.util;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

public final class BookingTimeRules {

    private static final ZoneId INDIA_ZONE =
            ZoneId.of("Asia/Kolkata");

    /** Bookings for a date open at 7:30 PM the previous day. */
    private static final LocalTime OPENS_AT = LocalTime.of(19, 30);

    /** Bookings and cancellations close at 1:45 PM on the operation day. */
    private static final LocalTime CLOSES_AT = LocalTime.of(13, 45);

    private BookingTimeRules() {
    }

    public static boolean isBookingOpen(LocalDate bookingDate) {
        return isBookingOpen(bookingDate, ZonedDateTime.now(INDIA_ZONE));
    }

    static boolean isBookingOpen(
            LocalDate bookingDate,
            ZonedDateTime currentTime) {

        ZonedDateTime now = currentTime.withZoneSameInstant(INDIA_ZONE);

        return !now.isBefore(opensAt(bookingDate))
                && now.isBefore(closesAt(bookingDate));
    }

    /** Cancellation is allowed until the same 1:45 PM cutoff. */
    public static boolean isCancellationOpen(LocalDate bookingDate) {
        ZonedDateTime now = ZonedDateTime.now(INDIA_ZONE);
        return now.isBefore(closesAt(bookingDate));
    }

    public static ZonedDateTime opensAt(LocalDate bookingDate) {
        return bookingDate
                .minusDays(1)
                .atTime(OPENS_AT)
                .atZone(INDIA_ZONE);
    }

    public static ZonedDateTime closesAt(LocalDate bookingDate) {
        return bookingDate
                .atTime(CLOSES_AT)
                .atZone(INDIA_ZONE);
    }
}