package com.shubus.backend.repository;


import java.time.LocalDate;
import java.util.List;
import java.util.Optional;


import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;


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


    @Query("""
        SELECT COUNT(b)
        FROM Booking b, Student s
        WHERE s.id = b.studentId
          AND b.afternoonAssignment.id = :assignmentId
          AND b.bookingDate = :bookingDate
          AND s.gender = :gender
        """)
    long countBookedSeatsByGender(
            @Param("assignmentId") Long assignmentId,
            @Param("bookingDate") LocalDate bookingDate,
            @Param("gender") String gender
    );
}