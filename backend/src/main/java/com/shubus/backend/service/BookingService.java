package com.shubus.backend.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Objects;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import com.shubus.backend.dto.BookingRequest;
import com.shubus.backend.dto.BookingResponse;
import com.shubus.backend.model.AfternoonRouteAssignment;
import com.shubus.backend.model.Booking;
import com.shubus.backend.model.Route;
import com.shubus.backend.model.Student;
import com.shubus.backend.model.StudentTransportProfile;
import com.shubus.backend.repository.AfternoonRouteAssignmentRepository;
import com.shubus.backend.repository.BookingRepository;
import com.shubus.backend.repository.RouteRepository;
import com.shubus.backend.repository.StudentRepository;
import com.shubus.backend.repository.StudentTransportProfileRepository;
import com.shubus.backend.util.BookingTimeRules;
import com.shubus.backend.util.SeatLayout;

@Service
public class BookingService {

    private final BookingRepository bookingRepository;
    private final StudentRepository studentRepository;
    private final AfternoonRouteAssignmentRepository assignmentRepository;
    private final StudentTransportProfileRepository profileRepository;
    private final RouteRepository routeRepository;

    public BookingService(
            BookingRepository bookingRepository,
            StudentRepository studentRepository,
            AfternoonRouteAssignmentRepository assignmentRepository,
            StudentTransportProfileRepository profileRepository,
            RouteRepository routeRepository) {

        this.bookingRepository = bookingRepository;
        this.studentRepository = studentRepository;
        this.assignmentRepository = assignmentRepository;
        this.profileRepository = profileRepository;
        this.routeRepository = routeRepository;
    }

    @Transactional
    public BookingResponse createBooking(BookingRequest request) {

        if (request == null
                || request.regNo() == null
                || request.assignmentId() == null
                || request.bookingDate() == null
                || request.seatNumber() == null) {

            throw new IllegalArgumentException(
                    "Registration number, assignment, date and seat are required");
        }

        Student student = studentRepository
                .findByRegNo(request.regNo().trim())
                .orElseThrow(() ->
                        apiError(HttpStatus.NOT_FOUND, "Student not found"));

        if (!Boolean.TRUE.equals(student.getActive())) {
            throw apiError(HttpStatus.FORBIDDEN,
                    "Student account is inactive");
        }

        StudentTransportProfile profile =
                profileRepository.findByStudentId(student.getId())
                        .orElseThrow(() ->
                                apiError(HttpStatus.NOT_FOUND,
                                        "Transport profile not found"));

        Route morningRoute =
                routeRepository.findByRouteNumber(
                        profile.getMorningRouteNumber())
                        .orElseThrow(() ->
                                apiError(HttpStatus.NOT_FOUND,
                                        "Morning route not found"));

        AfternoonRouteAssignment assignment =
                assignmentRepository.findById(
                        request.assignmentId())
                        .orElseThrow(() ->
                                apiError(HttpStatus.NOT_FOUND,
                                        "Assignment not found"));

        Route afternoonRoute = assignment.getRoute();

        // The requested date must match the actual assignment date.
        if (!assignment.getAssignmentDate()
                .equals(request.bookingDate())) {

            throw apiError(HttpStatus.BAD_REQUEST,
                    "Booking date does not match assignment date");
        }

        if (!BookingTimeRules.isBookingOpen(
                request.bookingDate())) {

            throw apiError(HttpStatus.CONFLICT,
                    "Booking is currently closed");
        }

        // Validate the selected seat.
        String seat = request.seatNumber().trim().toUpperCase();

        if (!SeatLayout.isValidSeat(seat)) {
            throw apiError(HttpStatus.BAD_REQUEST, "Invalid seat");
        }

        if (SeatLayout.isFacultySeat(seat)) {
            throw apiError(HttpStatus.BAD_REQUEST,
                    "Faculty seat cannot be booked");
        }

        if ("GIRL".equalsIgnoreCase(student.getGender())
                && !SeatLayout.isGirlsSeat(seat)) {

            throw apiError(HttpStatus.BAD_REQUEST,
                    "Girls can only book girls seats");
        }

        if ("BOY".equalsIgnoreCase(student.getGender())
                && !SeatLayout.isBoysSeat(seat)) {

            throw apiError(HttpStatus.BAD_REQUEST,
                    "Boys can only book boys seats");
        }

        // AC/Non-AC must match the student's transport profile.
        if (!sameValue(
                profile.getAcType(),
                afternoonRoute.getAcType())) {

            throw apiError(HttpStatus.BAD_REQUEST,
                    "Selected route does not match your AC/Non-AC profile");
        }

        // Regular assignments must be eligible for the morning route.
        if (!"SHUTTLE".equalsIgnoreCase(
                assignment.getAssignmentType())) {

            String[] allowedRoutes = morningRoute.getAllowedRoutes();

            if (!contains(
                    allowedRoutes,
                    afternoonRoute.getRouteCode())) {

                throw apiError(HttpStatus.BAD_REQUEST,
                        "Your morning route is not eligible for this afternoon route");
            }
        }

        // Enforce one booking per student per date.
        if (bookingRepository
                .findByStudentIdAndBookingDate(
                        student.getId(),
                        request.bookingDate())
                .isPresent()) {

            throw apiError(HttpStatus.CONFLICT,
                    "Student already has a booking for this date");
        }

        // Enforce seat uniqueness before attempting the insert.
        if (bookingRepository
                .existsByAfternoonAssignmentIdAndBookingDateAndSeatNumber(
                        assignment.getId(),
                        request.bookingDate(),
                        seat)) {

            throw apiError(HttpStatus.CONFLICT, "Seat already booked");
        }

        Booking booking = new Booking();

        booking.setStudentId(student.getId());
        booking.setAfternoonAssignment(assignment);
        booking.setBookingDate(request.bookingDate());
        booking.setSeatNumber(seat);
        booking.setBookedAt(
                LocalDateTime.now(ZoneId.of("Asia/Kolkata")));

        /*
         * Database unique constraints remain essential.
         * The pre-checks above improve error messages, but concurrent
         * requests can still race; PostgreSQL must enforce uniqueness.
         */
        Booking saved = bookingRepository.saveAndFlush(booking);

        return toResponse(saved, student, assignment);
    }

    @Transactional
    public void cancelBooking(String regNo, Long bookingId) {

        Student student = studentRepository
                .findByRegNo(regNo == null ? "" : regNo.trim())
                .orElseThrow(() ->
                        apiError(HttpStatus.NOT_FOUND, "Student not found"));

        Booking booking = bookingRepository
                .findById(bookingId)
                .orElseThrow(() ->
                        apiError(HttpStatus.NOT_FOUND, "Booking not found"));

        if (!booking.getStudentId().equals(student.getId())) {
            throw apiError(HttpStatus.FORBIDDEN,
                    "Booking does not belong to this student");
        }

        ZoneId indiaZone = ZoneId.of("Asia/Kolkata");

        ZonedDateTime now = ZonedDateTime.now(indiaZone);

        ZonedDateTime cancellationDeadline =
                booking.getBookingDate()
                        .atTime(12, 30)
                        .atZone(indiaZone);

        if (!now.isBefore(cancellationDeadline)) {
            throw apiError(HttpStatus.CONFLICT,
                    "Cancellation is closed");
        }

        bookingRepository.delete(booking);
    }

    @Transactional(readOnly = true)
    public BookingResponse getBooking(
            String regNo,
            LocalDate bookingDate) {

        Student student = studentRepository
                .findByRegNo(regNo == null ? "" : regNo.trim())
                .orElseThrow(() ->
                        apiError(HttpStatus.NOT_FOUND, "Student not found"));

        Booking booking = bookingRepository
                .findByStudentIdAndBookingDate(
                        student.getId(),
                        bookingDate)
                .orElseThrow(() ->
                        apiError(HttpStatus.NOT_FOUND, "No booking found"));

        return toResponse(
                booking,
                student,
                booking.getAfternoonAssignment());
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
                booking.getBookedAt());
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

    private ResponseStatusException apiError(
            HttpStatus status, String message) {
        return new ResponseStatusException(status, message);
    }
}