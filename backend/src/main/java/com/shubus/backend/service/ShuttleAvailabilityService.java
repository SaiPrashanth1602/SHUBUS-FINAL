package com.shubus.backend.service;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.shubus.backend.repository.AfternoonScheduleRepository;
import com.shubus.backend.util.ShuttleSlotRules;

@Service
public class ShuttleAvailabilityService {

    private final AfternoonScheduleRepository scheduleRepository;

    public ShuttleAvailabilityService(
            AfternoonScheduleRepository scheduleRepository) {
        this.scheduleRepository = scheduleRepository;
    }

    public boolean isOpen(Long assignmentId, LocalDate date) {
        List<Object[]> rows = scheduleRepository.getStudentSchedule(date);
        Object[] requestedAssignment = rows.stream()
                .filter(row -> assignmentId.equals(row[0]))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Assignment not found for booking date"));

        String assignmentType = (String) requestedAssignment[5];
        if (!"SHUTTLE".equalsIgnoreCase(assignmentType)) {
            return true;
        }

        String shuttleGroup = (String) requestedAssignment[6];
        return ShuttleSlotRules.isOpen(
                shuttleGroup,
                bookedSeatsByShuttleSlot(rows));
    }

    public static Map<String, Long> bookedSeatsByShuttleSlot(
            List<Object[]> scheduleRows) {
        Map<String, Long> bookedSeats = new HashMap<>();
        for (Object[] row : scheduleRows) {
            if (!"SHUTTLE".equalsIgnoreCase((String) row[5])
                    || row[6] == null) {
                continue;
            }

            String shuttleGroup = ShuttleSlotRules.normalize((String) row[6]);
            long count = ((Number) row[9]).longValue();
            bookedSeats.merge(shuttleGroup, count, Long::sum);
        }
        return bookedSeats;
    }
}
