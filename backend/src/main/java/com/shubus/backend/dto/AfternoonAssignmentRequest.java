package com.shubus.backend.dto;

import java.time.LocalDate;
import java.util.List;

public record AfternoonAssignmentRequest(
        LocalDate date,
        List<Long> routeIds,
        String assignmentType,
        String shuttleGroup
) {}