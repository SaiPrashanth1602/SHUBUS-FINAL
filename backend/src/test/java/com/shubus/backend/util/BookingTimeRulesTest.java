package com.shubus.backend.util;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import org.junit.jupiter.api.Test;

class BookingTimeRulesTest {

    private static final ZoneId INDIA_ZONE = ZoneId.of("Asia/Kolkata");

    @Test
    void opensAtTwoPmOnThePreviousDay() {
        LocalDate bookingDate = LocalDate.of(2026, 11, 10);

        assertFalse(BookingTimeRules.isBookingOpen(
                bookingDate,
                ZonedDateTime.of(2026, 11, 9, 13, 59, 59, 0, INDIA_ZONE)));
        assertTrue(BookingTimeRules.isBookingOpen(
                bookingDate,
                ZonedDateTime.of(2026, 11, 9, 14, 0, 0, 0, INDIA_ZONE)));
    }

    @Test
    void closesAtOneFortyFivePmOnTheBookingDay() {
        LocalDate bookingDate = LocalDate.of(2026, 11, 10);

        assertTrue(BookingTimeRules.isBookingOpen(
                bookingDate,
                ZonedDateTime.of(2026, 11, 10, 13, 44, 59, 0, INDIA_ZONE)));
        assertFalse(BookingTimeRules.isBookingOpen(
                bookingDate,
                ZonedDateTime.of(2026, 11, 10, 13, 45, 0, 0, INDIA_ZONE)));
    }

    @Test
    void comparesCurrentTimeByInstantUsingIndiaTime() {
        LocalDate bookingDate = LocalDate.of(2026, 11, 10);
        ZonedDateTime utcOpeningTime =
                ZonedDateTime.parse("2026-11-09T08:30:00Z");

        assertTrue(BookingTimeRules.isBookingOpen(
                bookingDate,
                utcOpeningTime));
    }
}
