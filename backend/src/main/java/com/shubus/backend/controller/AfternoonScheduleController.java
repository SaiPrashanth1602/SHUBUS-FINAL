package com.shubus.backend.controller;

import java.time.LocalDate;
import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.shubus.backend.dto.AfternoonScheduleResponse;
import com.shubus.backend.service.AfternoonScheduleService;

@RestController
@RequestMapping("/api/admin/schedule")
public class AfternoonScheduleController {

    private final AfternoonScheduleService scheduleService;

    public AfternoonScheduleController(
            AfternoonScheduleService scheduleService) {
        this.scheduleService = scheduleService;
    }

    @GetMapping
    public List<AfternoonScheduleResponse> getSchedule(
            @RequestParam LocalDate date) {

        return scheduleService.getSchedule(date);
    }
}