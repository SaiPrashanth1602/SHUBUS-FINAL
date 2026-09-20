package com.shubus.backend.dto;

public record BusRegistrationResponse(
        String regNo,
        Integer registeredBusNo,
        String routeName,
        String acType
) {
}