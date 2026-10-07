package com.shubus.backend.dto;

public record TransportProfileResponse(
        String regNo,
        String studentName,
        String morningRouteNumber,
        String morningRouteName,
        String acType
) {
}