package com.shubus.backend.dto;

import java.time.LocalDate;

public record BookingRequest(
        String regNo,
        Long assignmentId,
        LocalDate bookingDate,
        String seatNumber
) {
}