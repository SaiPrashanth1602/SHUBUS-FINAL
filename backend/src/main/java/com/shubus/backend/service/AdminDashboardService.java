package com.shubus.backend.service;

import java.time.LocalDate;
import java.util.List;
import java.util.Locale;

import org.springframework.stereotype.Service;

import com.shubus.backend.dto.AdminDashboardResponse;
import com.shubus.backend.repository.AdminDashboardRepository;
import com.shubus.backend.util.SeatLayout;

@Service
public class AdminDashboardService {

    private final AdminDashboardRepository repository;

    public AdminDashboardService(AdminDashboardRepository repository) {
        this.repository = repository;
    }

    public AdminDashboardResponse getOverview(LocalDate date) {
        int regularBuses = 0;
        long regularBookings = 0;

        int velacheryBuses = 0;
        long velacheryBookings = 0;
        int alandurBuses = 0;
        long alandurBookings = 0;
        int sholinganallurBuses = 0;
        long sholinganallurBookings = 0;
        int tambaramBuses = 0;
        long tambaramBookings = 0;

        List<Object[]> rows = repository.getOverview(date);
        for (Object[] row : rows) {
            String assignmentType = text(row[0]).toUpperCase(Locale.ROOT);
            String group = text(row[1]).toUpperCase(Locale.ROOT);
            int buses = ((Number) row[2]).intValue();
            long bookings = ((Number) row[3]).longValue();

            if ("REGULAR".equals(assignmentType)) {
                regularBuses += buses;
                regularBookings += bookings;
                continue;
            }

            // New records store slot IDs (A1-A5, V1-V3, S1, T1).
            // Also understand legacy destination-level group names so old
            // records continue to be represented correctly.
            if (group.matches("A[1-5]") || "ALANDUR_METRO".equals(group)) {
                alandurBuses += buses;
                alandurBookings += bookings;
            } else if (group.matches("V[1-3]") || "VELACHERY".equals(group)) {
                velacheryBuses += buses;
                velacheryBookings += bookings;
            } else if ("S1".equals(group) || "SHOLINGANALLUR".equals(group)) {
                sholinganallurBuses += buses;
                sholinganallurBookings += bookings;
            } else if ("T1".equals(group) || "TAMBARAM".equals(group)) {
                tambaramBuses += buses;
                tambaramBookings += bookings;
            }
        }

        int seatsPerBus = SeatLayout.getStudentBookableSeatCount();
        int regularCapacity = regularBuses * seatsPerBus;
        int velacheryCapacity = velacheryBuses * seatsPerBus;
        int alandurCapacity = alandurBuses * seatsPerBus;
        int sholinganallurCapacity = sholinganallurBuses * seatsPerBus;
        int tambaramCapacity = tambaramBuses * seatsPerBus;

        long totalBookings = regularBookings + velacheryBookings
                + alandurBookings + sholinganallurBookings + tambaramBookings;
        int totalCapacity = regularCapacity + velacheryCapacity + alandurCapacity
                + sholinganallurCapacity + tambaramCapacity;

        return new AdminDashboardResponse(
                regularBuses,
                regularBookings,
                regularCapacity,
                totalBookings,
                totalCapacity,
                new AdminDashboardResponse.ShuttleOverview(
                        velacheryBuses, velacheryBookings, velacheryCapacity),
                new AdminDashboardResponse.ShuttleOverview(
                        alandurBuses, alandurBookings, alandurCapacity),
                new AdminDashboardResponse.ShuttleOverview(
                        sholinganallurBuses, sholinganallurBookings, sholinganallurCapacity),
                new AdminDashboardResponse.ShuttleOverview(
                        tambaramBuses, tambaramBookings, tambaramCapacity)
        );
    }

    private String text(Object value) {
        return value == null ? "" : value.toString().trim();
    }
}
