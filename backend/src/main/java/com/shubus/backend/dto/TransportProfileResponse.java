package com.shubus.backend.dto;

public record TransportProfileResponse(
        String regNo,
        String studentName,
        String morningBusNumber,
        String acType,
        Boolean active
) {
}