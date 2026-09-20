package com.shubus.backend.dto;

public record BusResponse(
        String busNumber,
        String routeName,
        String numberPlate,
        String busType,
        String acType,
        Integer seatCapacity,
        Boolean active
) {
}