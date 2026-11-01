package com.shubus.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.Optional;

import com.shubus.backend.dto.BookingRequest;
import com.shubus.backend.model.AfternoonRouteAssignment;
import com.shubus.backend.model.Route;
import com.shubus.backend.model.Student;
import com.shubus.backend.model.StudentTransportProfile;
import com.shubus.backend.repository.AfternoonRouteAssignmentRepository;
import com.shubus.backend.repository.BookingRepository;
import com.shubus.backend.repository.RouteRepository;
import com.shubus.backend.repository.StudentRepository;
import com.shubus.backend.repository.StudentTransportProfileRepository;
import com.shubus.backend.util.BookingTimeRules;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

class BookingServiceTest {

    @Test
    void facultyOnlySeatIsRejectedBeforeBookingCanBeSaved() {
        BookingRepository bookingRepository = mock(BookingRepository.class);
        StudentRepository studentRepository = mock(StudentRepository.class);
        AfternoonRouteAssignmentRepository assignmentRepository =
                mock(AfternoonRouteAssignmentRepository.class);
        StudentTransportProfileRepository profileRepository =
                mock(StudentTransportProfileRepository.class);
        RouteRepository routeRepository = mock(RouteRepository.class);
        ShuttleAvailabilityService shuttleAvailabilityService =
                mock(ShuttleAvailabilityService.class);
        Student student = mock(Student.class);
        StudentTransportProfile profile = mock(StudentTransportProfile.class);
        Route morningRoute = mock(Route.class);
        Route afternoonRoute = mock(Route.class);
        AfternoonRouteAssignment assignment =
                mock(AfternoonRouteAssignment.class);
        LocalDate date = LocalDate.of(2026, 11, 1);

        when(studentRepository.findByRegNo("S1"))
                .thenReturn(Optional.of(student));
        when(student.getActive()).thenReturn(true);
        when(student.getId()).thenReturn(1L);
        when(student.getGender()).thenReturn("GIRL");
        when(profileRepository.findByStudentId(1L))
                .thenReturn(Optional.of(profile));
        when(profile.getMorningRouteNumber()).thenReturn("BUS-M");
        when(profile.getAcType()).thenReturn("AC");
        when(routeRepository.findByRouteNumber("BUS-M"))
                .thenReturn(Optional.of(morningRoute));
        when(assignmentRepository.findById(8L))
                .thenReturn(Optional.of(assignment));
        when(assignment.getAssignmentDate()).thenReturn(date);
        when(assignment.getRoute()).thenReturn(afternoonRoute);
        when(afternoonRoute.getAcType()).thenReturn("AC");
        when(shuttleAvailabilityService.isOpen(8L, date)).thenReturn(true);

        try (MockedStatic<BookingTimeRules> bookingWindow =
                mockStatic(BookingTimeRules.class)) {
            bookingWindow.when(() -> BookingTimeRules.isBookingOpen(date))
                    .thenReturn(true);

            ResponseStatusException error = assertThrows(
                    ResponseStatusException.class,
                    () -> new BookingService(
                            bookingRepository,
                            studentRepository,
                            assignmentRepository,
                            profileRepository,
                            routeRepository,
                            shuttleAvailabilityService)
                            .createBooking(new BookingRequest(
                                    "S1", 8L, date, "5A")));

            assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
            verify(bookingRepository, never()).saveAndFlush(
                    org.mockito.ArgumentMatchers.any());
        }
    }
}
