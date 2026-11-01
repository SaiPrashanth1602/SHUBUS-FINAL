package com.shubus.backend.util;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

public final class OperationalDateRules {

    private static final ZoneId INDIA_ZONE = ZoneId.of("Asia/Kolkata");
    private static final LocalTime OPERATIONAL_DATE_CUTOFF =
            LocalTime.of(13, 45);

    private OperationalDateRules() {
    }

    public static LocalDate getCurrentOperationalDate() {
        return getCurrentOperationalDate(
                ZonedDateTime.now(INDIA_ZONE)
        );
    }

    public static LocalDate getCurrentOperationalDate(
            ZonedDateTime currentTime
    ) {
        ZonedDateTime now = currentTime.withZoneSameInstant(INDIA_ZONE);
        LocalDate today = now.toLocalDate();

        boolean beforeCutoff =
                now.toLocalTime().isBefore(OPERATIONAL_DATE_CUTOFF);

        return beforeCutoff ? today : today.plusDays(1);
    }
}