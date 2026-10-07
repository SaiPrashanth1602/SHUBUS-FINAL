package com.shubus.backend.dto;

import java.time.LocalDate;

public record AfternoonRouteAssignmentResponse(
        Long id,
        Long routeId,
        String routeNumber,
        String routeName,
        String acType,
        LocalDate assignmentDate,
        String assignmentType,
        String shuttleGroup
) {}