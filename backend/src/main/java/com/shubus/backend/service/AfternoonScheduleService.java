package com.shubus.backend.service;

import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;

import com.shubus.backend.dto.AfternoonScheduleResponse;
import com.shubus.backend.repository.AfternoonScheduleRepository;
import com.shubus.backend.util.SeatLayout;

@Service
public class AfternoonScheduleService {

    private final AfternoonScheduleRepository scheduleRepository;

    public AfternoonScheduleService(
            AfternoonScheduleRepository scheduleRepository) {
        this.scheduleRepository = scheduleRepository;
    }

    public List<AfternoonScheduleResponse> getSchedule(
            LocalDate date) {

        return scheduleRepository.getSchedule(date)
                .stream()
                .map(row -> {

                    Long assignmentId =
                            (Long) row[0];

                    Long routeId =
                            (Long) row[1];

                    String routeNumber =
                            (String) row[2];

                    String routeName =
                            (String) row[3];

                    String acType =
                            (String) row[4];

                    String assignmentType =
                            (String) row[5];

                    String shuttleGroup =
                            (String) row[6];

                    LocalDate assignmentDate =
                            (LocalDate) row[7];

                    // Query projection: row[8] is routeCode; row[9] is COUNT(b.id).
                    long bookedSeats =
                            ((Number) row[9]).longValue();

                    int totalSeats = SeatLayout.getStudentBookableSeatCount();

                    long availableSeats =
                            totalSeats - bookedSeats;

                    return new AfternoonScheduleResponse(
                            assignmentId,
                            routeId,
                            routeNumber,
                            routeName,
                            acType,
                            assignmentType,
                            shuttleGroup,
                            assignmentDate,
                            totalSeats,
                            bookedSeats,
                            availableSeats
                    );
                })
                .toList();
    }
}