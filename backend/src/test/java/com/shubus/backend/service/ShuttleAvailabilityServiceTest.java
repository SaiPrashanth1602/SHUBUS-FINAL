package com.shubus.backend.service;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;

import com.shubus.backend.repository.AfternoonScheduleRepository;
import org.junit.jupiter.api.Test;

class ShuttleAvailabilityServiceTest {

    @Test
    void opensNextSlotOnlyAfterPreviousSlotHasFiftyBookings() {
        AfternoonScheduleRepository scheduleRepository =
                mock(AfternoonScheduleRepository.class);
        LocalDate date = LocalDate.of(2026, 11, 1);
        Object[] firstSlot = {
                1L, 10L, "A1", "Alandur", "AC", "SHUTTLE", "A1",
                date, "A1", 49L
        };
        Object[] secondSlot = {
                2L, 11L, "A2", "Alandur", "AC", "SHUTTLE", "A2",
                date, "A2", 0L
        };
        when(scheduleRepository.getStudentSchedule(date))
                .thenReturn(List.of(firstSlot, secondSlot))
                .thenReturn(List.of(
                        new Object[] {
                                1L, 10L, "A1", "Alandur", "AC", "SHUTTLE", "A1",
                                date, "A1", 50L
                        },
                        secondSlot));

        ShuttleAvailabilityService service =
                new ShuttleAvailabilityService(scheduleRepository);

        assertFalse(service.isOpen(2L, date));
        assertTrue(service.isOpen(2L, date));
    }
}
