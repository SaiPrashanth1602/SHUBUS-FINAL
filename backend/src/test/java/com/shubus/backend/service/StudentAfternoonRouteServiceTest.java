package com.shubus.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import com.shubus.backend.dto.StudentAfternoonRouteResponse;
import com.shubus.backend.model.Route;
import com.shubus.backend.model.Student;
import com.shubus.backend.model.StudentTransportProfile;
import com.shubus.backend.repository.AfternoonScheduleRepository;
import com.shubus.backend.repository.RouteRepository;
import com.shubus.backend.repository.StudentRepository;
import com.shubus.backend.repository.StudentTransportProfileRepository;
import org.junit.jupiter.api.Test;

class StudentAfternoonRouteServiceTest {

    @Test
    void scheduleReportsOnlyStudentBookableSeats() {
        StudentRepository studentRepository = mock(StudentRepository.class);
        StudentTransportProfileRepository profileRepository =
                mock(StudentTransportProfileRepository.class);
        RouteRepository routeRepository = mock(RouteRepository.class);
        AfternoonScheduleRepository scheduleRepository =
                mock(AfternoonScheduleRepository.class);

        Student student = mock(Student.class);
        StudentTransportProfile profile = mock(StudentTransportProfile.class);
        Route morningRoute = mock(Route.class);
        LocalDate date = LocalDate.of(2026, 11, 1);

        when(studentRepository.findByRegNo("S1"))
                .thenReturn(Optional.of(student));
        when(student.getActive()).thenReturn(true);
        when(student.getId()).thenReturn(1L);
        when(profileRepository.findByStudentId(1L))
                .thenReturn(Optional.of(profile));
        when(profile.getMorningRouteNumber()).thenReturn("BUS-1");
        when(profile.getAcType()).thenReturn("AC");
        when(routeRepository.findByRouteNumber("BUS-1"))
                .thenReturn(Optional.of(morningRoute));
        when(morningRoute.getAllowedRoutes()).thenReturn(new String[] {"R2"});
        when(scheduleRepository.getStudentSchedule(date)).thenReturn(
                Collections.singletonList(new Object[] {
                        10L, 2L, "BUS-2", "South", "AC", "REGULAR", null,
                        date, "R2", 3L
                }));

        StudentAfternoonRouteService service =
                new StudentAfternoonRouteService(
                        studentRepository,
                        profileRepository,
                        routeRepository,
                        scheduleRepository);

        List<StudentAfternoonRouteResponse> results =
                service.getAvailableRoutes("S1", date);

        assertEquals(1, results.size());
        assertEquals(50, results.get(0).totalSeats());
        assertEquals(3, results.get(0).bookedSeats());
        assertEquals(47, results.get(0).availableSeats());
    }
}
