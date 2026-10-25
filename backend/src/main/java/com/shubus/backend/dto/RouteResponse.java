package com.shubus.backend.dto;

public record RouteResponse(
        Long id,
        String routeNumber,
        String routeCode,
        String routeName,
        String acType,
        String[] allowedRoutes,
        boolean defaultAfternoon
) {}