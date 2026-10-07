package com.shubus.backend.model;

import java.time.LocalDate;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "bookings")
public class Booking {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "student_id", nullable = false)
    private Long studentId;

    @ManyToOne
    @JoinColumn(name = "afternoon_assignment_id", nullable = false)
    private AfternoonRouteAssignment afternoonAssignment;

    @Column(name = "booking_date", nullable = false)
    private LocalDate bookingDate;

    @Column(name = "seat_number")
    private String seatNumber;

    @Column(name = "booked_at", nullable = false)
    private LocalDateTime bookedAt;

    public Long getId() {
        return id;
    }

    public Long getStudentId() {
        return studentId;
    }

    public void setStudentId(Long studentId) {
        this.studentId = studentId;
    }

    public AfternoonRouteAssignment getAfternoonAssignment() {
        return afternoonAssignment;
    }

    public void setAfternoonAssignment(
            AfternoonRouteAssignment afternoonAssignment) {
        this.afternoonAssignment = afternoonAssignment;
    }

    public LocalDate getBookingDate() {
        return bookingDate;
    }

    public void setBookingDate(LocalDate bookingDate) {
        this.bookingDate = bookingDate;
    }

    public String getSeatNumber() {
    return seatNumber;
}

public void setSeatNumber(String seatNumber) {
    this.seatNumber = seatNumber;
}

    public LocalDateTime getBookedAt() {
        return bookedAt;
    }

    public void setBookedAt(LocalDateTime bookedAt) {
        this.bookedAt = bookedAt;
    }
}