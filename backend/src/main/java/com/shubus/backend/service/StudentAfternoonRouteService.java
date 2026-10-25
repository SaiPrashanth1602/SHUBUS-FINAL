package com.shubus.backend.service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import com.shubus.backend.dto.StudentAfternoonRouteResponse;
import com.shubus.backend.model.Route;
import com.shubus.backend.model.Student;
import com.shubus.backend.model.StudentTransportProfile;
import com.shubus.backend.repository.AfternoonScheduleRepository;
import com.shubus.backend.repository.RouteRepository;
import com.shubus.backend.repository.StudentRepository;
import com.shubus.backend.repository.StudentTransportProfileRepository;
import com.shubus.backend.util.SeatLayout;

@Service
public class StudentAfternoonRouteService {

    private final StudentRepository studentRepository;
    private final StudentTransportProfileRepository profileRepository;
    private final RouteRepository routeRepository;
    private final AfternoonScheduleRepository scheduleRepository;

    public StudentAfternoonRouteService(
            StudentRepository studentRepository,
            StudentTransportProfileRepository profileRepository,
            RouteRepository routeRepository,
            AfternoonScheduleRepository scheduleRepository) {

        this.studentRepository = studentRepository;
        this.profileRepository = profileRepository;
        this.routeRepository = routeRepository;
        this.scheduleRepository = scheduleRepository;
    }

    @Transactional(readOnly = true)
    public List<StudentAfternoonRouteResponse> getAvailableRoutes(
            String regNo,
            LocalDate date) {

        if (date == null) {
            throw new IllegalArgumentException(
                    "Booking date is required");
        }

        Student student = studentRepository.findByRegNo(regNo == null ? "" : regNo.trim())
                .orElseThrow(() ->
                        new ResponseStatusException(
                                HttpStatus.NOT_FOUND, "Student not found"));

        if (!Boolean.TRUE.equals(student.getActive())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Student account is inactive");
        }

        StudentTransportProfile profile =
                profileRepository.findByStudentId(student.getId())
                        .orElseThrow(() ->
                                new ResponseStatusException(
                                        HttpStatus.NOT_FOUND,
                                        "Transport profile not found"));

        Route morningRoute =
                routeRepository.findByRouteNumber(
                        profile.getMorningRouteNumber())
                        .orElseThrow(() ->
                                new ResponseStatusException(
                                        HttpStatus.NOT_FOUND,
                                        "Morning route not found"));

        String[] allowedRoutes = morningRoute.getAllowedRoutes();

        List<Object[]> rows =
                scheduleRepository.getStudentSchedule(date);

        List<StudentAfternoonRouteResponse> result =
                new ArrayList<>();

        for (Object[] row : rows) {

            Long assignmentId =
                    ((Number) row[0]).longValue();

            Long routeId =
                    ((Number) row[1]).longValue();

            String routeNumber = (String) row[2];
            String routeName = (String) row[3];
            String acType = (String) row[4];
            String assignmentType = (String) row[5];
            String shuttleGroup = (String) row[6];
            LocalDate assignmentDate = (LocalDate) row[7];

            String routeCode = (String) row[8];

            long bookedSeats =
                ((Number) row[9]).longValue();

            // Transport profile and afternoon route must match.
            if (!sameValue(profile.getAcType(), acType)) {
                continue;
            }

            boolean eligible;

            if ("SHUTTLE".equalsIgnoreCase(assignmentType)) {
    eligible = true;
} else {
    eligible = contains(allowedRoutes, routeCode);
}

            if (!eligible) {
                continue;
            }

            /*
             * SeatLayout contains 55 valid seats, including faculty-only seats.
             *
             * Keep this count aligned with SeatLayout.
             */
            int totalSeats = SeatLayout.getStudentBookableSeatCount();

            long availableSeats =
                    Math.max(0L, totalSeats - bookedSeats);

            result.add(
                    new StudentAfternoonRouteResponse(
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
                    )
            );
        }

        return result;
    }

    private boolean contains(
            String[] allowedRoutes,
            String routeNumber) {

        if (allowedRoutes == null || routeNumber == null) {
            return false;
        }

        for (String allowedRoute : allowedRoutes) {
            if (allowedRoute != null
                    && allowedRoute.trim().equalsIgnoreCase(
                            routeNumber.trim())) {
                return true;
            }
        }

        return false;
    }

    private boolean sameValue(String first, String second) {
        return first != null
                && second != null
                && Objects.equals(
                        first.trim().toUpperCase(),
                        second.trim().toUpperCase());
    }
}