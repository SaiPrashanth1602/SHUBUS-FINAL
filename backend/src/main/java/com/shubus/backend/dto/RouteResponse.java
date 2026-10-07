package com.shubus.backend.dto;

public record RouteResponse(
        Long id,
        String routeNumber,
        String routeName,
        String acType,
        String[] allowedRoutes,
        boolean defaultAfternoon
) {}