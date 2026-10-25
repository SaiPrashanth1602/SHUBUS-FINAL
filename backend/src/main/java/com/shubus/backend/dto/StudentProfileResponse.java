package com.shubus.backend.dto;

/** Combined student and transport data for the SHUBUS student module. */
public record StudentProfileResponse(
        String regNo,
        String name,
        Boolean active,
        String morningRouteNumber,
        String morningRouteName,
        String acType
) {
}
