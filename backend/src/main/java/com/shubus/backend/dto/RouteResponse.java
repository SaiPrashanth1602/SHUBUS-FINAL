package com.shubus.backend.dto;

public record RouteResponse(
        Long id,
        String name,
        String routeType,
        Boolean active
) {
}