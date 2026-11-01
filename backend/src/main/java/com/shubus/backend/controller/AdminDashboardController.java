package com.shubus.backend.controller;

import java.time.LocalDate;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.shubus.backend.dto.AdminDashboardResponse;
import com.shubus.backend.service.AdminDashboardService;
import com.shubus.backend.util.OperationalDateRules;

@RestController
@RequestMapping("/api/admin/dashboard")
public class AdminDashboardController {

    private final AdminDashboardService dashboardService;

    public AdminDashboardController(
            AdminDashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping("/operational-date")
    public Map<String, LocalDate> getCurrentOperationalDate() {
        LocalDate operationalDate =
                OperationalDateRules.getCurrentOperationalDate();

        return Map.of("operationalDate", operationalDate);
    }

    @GetMapping
    public AdminDashboardResponse getDashboard(
            @RequestParam LocalDate date) {

        return dashboardService.getOverview(date);
    }
}