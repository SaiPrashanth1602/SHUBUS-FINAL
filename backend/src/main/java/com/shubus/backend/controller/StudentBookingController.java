package com.shubus.backend.controller;

import java.time.LocalDate;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.shubus.backend.dto.BookingRequest;
import com.shubus.backend.dto.BookingResponse;
import com.shubus.backend.service.BookingService;

@RestController
@RequestMapping("/api/students")
public class StudentBookingController {

    private final BookingService bookingService;

    public StudentBookingController(BookingService bookingService) {
        this.bookingService = bookingService;
    }

    @PostMapping("/bookings")
    public ResponseEntity<BookingResponse> createBooking(
            @RequestBody BookingRequest request) {

        return ResponseEntity.ok(
                bookingService.createBooking(request));
    }

    @GetMapping("/{regNo}/bookings")
    public ResponseEntity<BookingResponse> getBooking(
            @PathVariable String regNo,
            @RequestParam LocalDate date) {

        try {
            return ResponseEntity.ok(
                    bookingService.getBooking(regNo, date));
        } catch (RuntimeException error) {
            if ("No booking found".equals(error.getMessage())) {
                return ResponseEntity.notFound().build();
            }

            throw error;
        }
    }

    @DeleteMapping("/{regNo}/bookings/{bookingId}")
    public ResponseEntity<Void> cancelBooking(
            @PathVariable String regNo,
            @PathVariable Long bookingId) {

        bookingService.cancelBooking(regNo, bookingId);

        return ResponseEntity.noContent().build();
    }
}