package com.shubus.backend.service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.shubus.backend.dto.SeatResponse;
import com.shubus.backend.model.Booking;
import com.shubus.backend.model.Student;
import com.shubus.backend.repository.BookingRepository;
import com.shubus.backend.repository.StudentRepository;
import com.shubus.backend.util.SeatLayout;

@Service
public class SeatService {

    private final BookingRepository bookingRepository;
    private final StudentRepository studentRepository;
    private final ShuttleAvailabilityService shuttleAvailabilityService;

    public SeatService(
            BookingRepository bookingRepository,
            StudentRepository studentRepository,
            ShuttleAvailabilityService shuttleAvailabilityService) {

        this.bookingRepository = bookingRepository;
        this.studentRepository = studentRepository;
        this.shuttleAvailabilityService = shuttleAvailabilityService;
    }

    public List<SeatResponse> getSeats(
            String regNo,
            Long assignmentId,
            LocalDate bookingDate) {

        Student student = studentRepository
                .findByRegNo(regNo == null ? "" : regNo.trim())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Student not found"));

        if (!Boolean.TRUE.equals(student.getActive())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Student account is inactive");
        }

        if (!shuttleAvailabilityService.isOpen(assignmentId, bookingDate)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Shuttle is not open for booking");
        }

        List<Booking> bookings =
                bookingRepository
                        .findByAfternoonAssignmentIdAndBookingDate(
                                assignmentId,
                                bookingDate);

        Set<String> bookedSeats = new HashSet<>();

        for (Booking booking : bookings) {
            bookedSeats.add(booking.getSeatNumber());
        }

        List<SeatResponse> seats = new ArrayList<>();

        for (String seat : SeatLayout.getAllSeats()) {

            String status;

            if (SeatLayout.isFacultySeat(seat)) {
                status = "FACULTY";
            } else if (bookedSeats.contains(seat)) {
                status = "BOOKED";
            } else if ("GIRL".equals(student.getGender())
                    && !SeatLayout.isGirlsSeat(seat)) {
                status = "GENDER_RESTRICTED";
            } else if ("BOY".equals(student.getGender())
                    && !SeatLayout.isBoysSeat(seat)) {
                status = "GENDER_RESTRICTED";
            } else {
                status = "AVAILABLE";
            }

            seats.add(new SeatResponse(seat, status));
        }

        return seats;
    }
}