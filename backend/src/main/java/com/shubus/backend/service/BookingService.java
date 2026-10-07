package com.shubus.backend.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import org.springframework.stereotype.Service;

import com.shubus.backend.dto.BookingRequest;
import com.shubus.backend.dto.BookingResponse;
import com.shubus.backend.model.AfternoonRouteAssignment;
import com.shubus.backend.model.Booking;
import com.shubus.backend.model.Route;
import com.shubus.backend.model.Student;
import com.shubus.backend.repository.AfternoonRouteAssignmentRepository;
import com.shubus.backend.repository.BookingRepository;
import com.shubus.backend.repository.StudentRepository;
import com.shubus.backend.util.BookingTimeRules;
import com.shubus.backend.util.SeatLayout;
@Service
public class BookingService {

    private final BookingRepository bookingRepository;
    private final StudentRepository studentRepository;
    private final AfternoonRouteAssignmentRepository assignmentRepository;

    public BookingService(
            BookingRepository bookingRepository,
            StudentRepository studentRepository,
            AfternoonRouteAssignmentRepository assignmentRepository) {

        this.bookingRepository = bookingRepository;
        this.studentRepository = studentRepository;
        this.assignmentRepository = assignmentRepository;
    }

    public BookingResponse createBooking(BookingRequest request) {

        Student student = studentRepository
                .findByRegNo(request.regNo())
                .orElseThrow(() -> new RuntimeException("Student not found"));

        AfternoonRouteAssignment assignment = assignmentRepository
                .findById(request.assignmentId())
                .orElseThrow(() -> new RuntimeException("Assignment not found"));

        if (!assignment.getAssignmentDate().equals(request.bookingDate())) {
    throw new RuntimeException("Booking date does not match assignment date");
}

if (!BookingTimeRules.isBookingOpen(request.bookingDate())) {
    throw new RuntimeException("Booking is currently closed");
}

if (!SeatLayout.isValidSeat(request.seatNumber())) {
    throw new RuntimeException("Invalid seat");
}

if (SeatLayout.isFacultySeat(request.seatNumber())) {
    throw new RuntimeException("Faculty seat cannot be booked");
}

if ("GIRL".equals(student.getGender())
        && !SeatLayout.isGirlsSeat(request.seatNumber())) {
    throw new RuntimeException("Girls can only book girls seats");
}

if ("BOY".equals(student.getGender())
        && !SeatLayout.isBoysSeat(request.seatNumber())) {
    throw new RuntimeException("Boys can only book boys seats");
}

if (bookingRepository
        .findByStudentIdAndBookingDate(
                student.getId(),
                request.bookingDate())
        .isPresent()) {

    throw new RuntimeException("Student already has a booking for this date");
}

        

        if (bookingRepository
                .existsByAfternoonAssignmentIdAndBookingDateAndSeatNumber(
                        request.assignmentId(),
                        request.bookingDate(),
                        request.seatNumber())) {

            throw new RuntimeException("Seat already booked");
        }

        Booking booking = new Booking();

        booking.setStudentId(student.getId());
        booking.setAfternoonAssignment(assignment);
        booking.setBookingDate(request.bookingDate());
        booking.setSeatNumber(request.seatNumber());
        booking.setBookedAt(LocalDateTime.now());

        Booking saved = bookingRepository.save(booking);

        return toResponse(saved, student, assignment);
    }

    public void cancelBooking(String regNo, Long bookingId) {

    Student student = studentRepository
            .findByRegNo(regNo)
            .orElseThrow(() -> new RuntimeException("Student not found"));

    Booking booking = bookingRepository
            .findById(bookingId)
            .orElseThrow(() -> new RuntimeException("Booking not found"));

    if (!booking.getStudentId().equals(student.getId())) {
        throw new RuntimeException("Booking does not belong to this student");
    }

    ZoneId indiaZone = ZoneId.of("Asia/Kolkata");

    ZonedDateTime now = ZonedDateTime.now(indiaZone);

    ZonedDateTime cancellationDeadline =
            booking.getBookingDate()
                    .atTime(12, 30)
                    .atZone(indiaZone);

    if (!now.isBefore(cancellationDeadline)) {
        throw new RuntimeException("Cancellation is closed");
    }

    bookingRepository.delete(booking);
}

public BookingResponse getBooking(
        String regNo,
        LocalDate bookingDate) {

    Student student = studentRepository
            .findByRegNo(regNo)
            .orElseThrow(() -> new RuntimeException("Student not found"));

    Booking booking = bookingRepository
            .findByStudentIdAndBookingDate(
                    student.getId(),
                    bookingDate)
            .orElseThrow(() -> new RuntimeException("No booking found"));

    return toResponse(
            booking,
            student,
            booking.getAfternoonAssignment()
    );
}

private BookingResponse toResponse(
            Booking booking,
            Student student,
            AfternoonRouteAssignment assignment) {

        Route route = assignment.getRoute();

        return new BookingResponse(
                booking.getId(),
                student.getRegNo(),
                assignment.getId(),
                route.getRouteNumber(),
                route.getRouteName(),
                route.getAcType(),
                assignment.getAssignmentType(),
                assignment.getShuttleGroup(),
                booking.getBookingDate(),
                booking.getSeatNumber(),
                booking.getBookedAt()
        );
    }
}