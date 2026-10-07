package com.shubus.backend.service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Service;

import com.shubus.backend.dto.StudentAfternoonRouteResponse;
import com.shubus.backend.model.Route;
import com.shubus.backend.model.Student;
import com.shubus.backend.model.StudentTransportProfile;
import com.shubus.backend.repository.AfternoonScheduleRepository;
import com.shubus.backend.repository.RouteRepository;
import com.shubus.backend.repository.StudentRepository;
import com.shubus.backend.repository.StudentTransportProfileRepository;

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

    public List<StudentAfternoonRouteResponse> getAvailableRoutes(
            String regNo,
            LocalDate date) {

        Student student = studentRepository.findByRegNo(regNo)
                .orElseThrow(() -> new RuntimeException("Student not found"));

        StudentTransportProfile profile =
                profileRepository.findByStudentId(student.getId())
                        .orElseThrow(() ->
                                new RuntimeException("Transport profile not found"));

        Route morningRoute =
                routeRepository.findByRouteNumber(
                        profile.getMorningRouteNumber()
                ).orElseThrow(() ->
                        new RuntimeException("Morning route not found"));

        String[] allowedRoutes = morningRoute.getAllowedRoutes();

        List<Object[]> rows =
                scheduleRepository.getStudentSchedule(date);

        List<StudentAfternoonRouteResponse> result =
                new ArrayList<>();

        for (Object[] row : rows) {

            String routeNumber = (String) row[2];
            String acType = (String) row[4];
            String assignmentType = (String) row[5];

            boolean acMatches =
                    profile.getAcType().equals(acType);

            if (!acMatches) {
                continue;
            }

            boolean eligible;

            if ("SHUTTLE".equals(assignmentType)) {
                // Shuttle buses bypass morning-route restriction
                eligible = true;
            } else {
                // Regular buses must be allowed for the student's
                // registered morning route
                eligible = contains(allowedRoutes, routeNumber);
            }

            if (!eligible) {
                continue;
            }

            long bookedSeats = ((Number) row[8]).longValue();
            int totalSeats = 55;

            result.add(
                    new StudentAfternoonRouteResponse(
                            ((Number) row[0]).longValue(),
                            ((Number) row[1]).longValue(),
                            routeNumber,
                            (String) row[3],
                            acType,
                            assignmentType,
                            (String) row[6],
                            (LocalDate) row[7],
                            totalSeats,
                            bookedSeats,
                            totalSeats - (int) bookedSeats
                    )
            );
        }

        return result;
    }

    private boolean contains(String[] routes, String routeNumber) {

        if (routes == null) {
            return false;
        }

        for (String route : routes) {
            if (routeNumber.equals(route)) {
                return true;
            }
        }

        return false;
    }
}