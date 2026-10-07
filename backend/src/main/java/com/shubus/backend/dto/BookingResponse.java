package com.shubus.backend.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

public record BookingResponse(
        Long bookingId,
        String regNo,
        Long assignmentId,
        String routeNumber,
        String routeName,
        String acType,
        String assignmentType,
        String shuttleGroup,
        LocalDate bookingDate,
        String seatNumber,
        LocalDateTime bookedAt
) {
}