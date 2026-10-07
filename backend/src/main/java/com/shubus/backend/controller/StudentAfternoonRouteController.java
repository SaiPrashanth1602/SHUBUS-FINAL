package com.shubus.backend.controller;

import java.time.LocalDate;
import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.shubus.backend.dto.StudentAfternoonRouteResponse;
import com.shubus.backend.service.StudentAfternoonRouteService;

@RestController
@RequestMapping("/api/students")
public class StudentAfternoonRouteController {

    private final StudentAfternoonRouteService service;

    public StudentAfternoonRouteController(
            StudentAfternoonRouteService service) {
        this.service = service;
    }

    @GetMapping("/{regNo}/afternoon-routes")
    public List<StudentAfternoonRouteResponse> getAvailableRoutes(
            @PathVariable String regNo,
            @RequestParam LocalDate date) {

        return service.getAvailableRoutes(regNo, date);
    }
}