package com.shubus.backend.util;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;

public final class BookingTimeRules {

    private static final ZoneId INDIA_ZONE =
            ZoneId.of("Asia/Kolkata");

    private BookingTimeRules() {
    }

    public static boolean isBookingOpen(LocalDate bookingDate) {

        ZonedDateTime now =
                ZonedDateTime.now(INDIA_ZONE);

        ZonedDateTime opensAt =
                bookingDate
                        .minusDays(1)
                        .atTime(19, 0)
                        .atZone(INDIA_ZONE);

        ZonedDateTime closesAt =
                bookingDate
                        .atTime(13, 45)
                        .atZone(INDIA_ZONE);

        return !now.isBefore(opensAt)
                && now.isBefore(closesAt);
    }
}