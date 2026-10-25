package com.shubus.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import com.shubus.backend.dto.SeatResponse;
import com.shubus.backend.model.Student;
import com.shubus.backend.repository.BookingRepository;
import com.shubus.backend.repository.StudentRepository;
import org.junit.jupiter.api.Test;

class SeatServiceTest {

    @Test
    void facultySeatsAreUnavailableToStudents() {
        BookingRepository bookingRepository = mock(BookingRepository.class);
        StudentRepository studentRepository = mock(StudentRepository.class);
        Student student = mock(Student.class);
        when(studentRepository.findByRegNo("S1"))
                .thenReturn(Optional.of(student));
        when(student.getActive()).thenReturn(true);
        when(student.getGender()).thenReturn("GIRL");
        when(bookingRepository.findByAfternoonAssignmentIdAndBookingDate(
                9L, LocalDate.of(2026, 11, 1)))
                .thenReturn(List.of());

        List<SeatResponse> seats = new SeatService(
                bookingRepository, studentRepository)
                .getSeats("S1", 9L, LocalDate.of(2026, 11, 1));

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
