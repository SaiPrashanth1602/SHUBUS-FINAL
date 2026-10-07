package com.shubus.backend.controller;

import java.time.LocalDate;
import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.shubus.backend.dto.SeatResponse;
import com.shubus.backend.service.SeatService;

@RestController
@RequestMapping("/api/students")
public class StudentSeatController {

    private final SeatService seatService;

    public StudentSeatController(SeatService seatService) {
        this.seatService = seatService;
    }

    @GetMapping("/{regNo}/afternoon-routes/{assignmentId}/seats")
    public List<SeatResponse> getSeats(
            @PathVariable String regNo,
            @PathVariable Long assignmentId,
            @RequestParam LocalDate date) {

        return seatService.getSeats(
                regNo,
                assignmentId,
                date
        );
    }
}