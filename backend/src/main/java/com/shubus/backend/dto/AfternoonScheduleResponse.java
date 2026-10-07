package com.shubus.backend.dto;

import java.time.LocalDate;

public record AfternoonScheduleResponse(
        Long assignmentId,
        Long routeId,
        String routeNumber,
        String routeName,
        String acType,
        String assignmentType,
        String shuttleGroup,
        LocalDate assignmentDate,
        int totalSeats,
        long bookedSeats,
        long availableSeats
) {}