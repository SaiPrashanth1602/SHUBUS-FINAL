package com.shubus.backend.repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.shubus.backend.model.Booking;

public interface BookingRepository extends JpaRepository<Booking, Long> {

    Optional<Booking> findByStudentIdAndBookingDate(
            Long studentId,
            LocalDate bookingDate
    );

    List<Booking> findByAfternoonAssignmentIdAndBookingDate(
        Long assignmentId,
        LocalDate bookingDate
);

    boolean existsByAfternoonAssignmentIdAndBookingDateAndSeatNumber(
            Long assignmentId,
            LocalDate bookingDate,
            String seatNumber
    );
}