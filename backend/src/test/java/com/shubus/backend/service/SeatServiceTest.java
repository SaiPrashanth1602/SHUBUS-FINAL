package com.shubus.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import com.shubus.backend.dto.SeatResponse;
import com.shubus.backend.model.Student;
import com.shubus.backend.repository.BookingRepository;
import com.shubus.backend.repository.StudentRepository;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

class SeatServiceTest {

    @Test
    void closedShuttleDoesNotExposeSeatPicker() {
        BookingRepository bookingRepository = mock(BookingRepository.class);
        StudentRepository studentRepository = mock(StudentRepository.class);
        ShuttleAvailabilityService shuttleAvailabilityService =
                mock(ShuttleAvailabilityService.class);
        Student student = mock(Student.class);
        LocalDate date = LocalDate.of(2026, 11, 1);
        when(studentRepository.findByRegNo("S1"))
                .thenReturn(Optional.of(student));
        when(student.getActive()).thenReturn(true);
        when(shuttleAvailabilityService.isOpen(9L, date)).thenReturn(false);

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> new SeatService(
                        bookingRepository,
                        studentRepository,
                        shuttleAvailabilityService)
                        .getSeats("S1", 9L, date));

        assertEquals(HttpStatus.CONFLICT, error.getStatusCode());
        verify(bookingRepository, never())
                .findByAfternoonAssignmentIdAndBookingDate(9L, date);
    }

    @Test
    void facultySeatsAreUnavailableToStudents() {
        BookingRepository bookingRepository = mock(BookingRepository.class);
        StudentRepository studentRepository = mock(StudentRepository.class);
        ShuttleAvailabilityService shuttleAvailabilityService =
                mock(ShuttleAvailabilityService.class);
        Student student = mock(Student.class);
        LocalDate date = LocalDate.of(2026, 11, 1);
        when(studentRepository.findByRegNo("S1"))
                .thenReturn(Optional.of(student));
        when(student.getActive()).thenReturn(true);
        when(student.getGender()).thenReturn("GIRL");
        when(shuttleAvailabilityService.isOpen(9L, date)).thenReturn(true);
        when(bookingRepository.findByAfternoonAssignmentIdAndBookingDate(
                9L, date))
                .thenReturn(List.of());

        List<SeatResponse> seats = new SeatService(
                bookingRepository, studentRepository, shuttleAvailabilityService)
                .getSeats("S1", 9L, date);

        assertEquals(55, seats.size());
        assertEquals(
                5,
                seats.stream().filter(seat -> "FACULTY".equals(seat.status()))
                        .count());
        assertEquals(
                19,
                seats.stream().filter(seat -> "AVAILABLE".equals(seat.status()))
                        .count());
        assertEquals(
                31,
                seats.stream()
                        .filter(seat -> "GENDER_RESTRICTED".equals(seat.status()))
                        .count());
        assertEquals(
                50,
                seats.stream()
                        .filter(seat -> !"FACULTY".equals(seat.status()))
                        .count());
    }
}
