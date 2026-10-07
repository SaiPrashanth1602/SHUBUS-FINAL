package com.shubus.backend.service;

import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;

import com.shubus.backend.dto.AdminDashboardResponse;
import com.shubus.backend.repository.AdminDashboardRepository;

@Service
public class AdminDashboardService {

    private final AdminDashboardRepository repository;

    public AdminDashboardService(
            AdminDashboardRepository repository) {
        this.repository = repository;
    }

    public AdminDashboardResponse getOverview(
            LocalDate date) {

        int regularBuses = 0;
        long regularBookings = 0;

        int velacheryBuses = 0;
        long velacheryBookings = 0;

        int alandurBuses = 0;
        long alandurBookings = 0;

        List<Object[]> rows =
                repository.getOverview(date);

        for (Object[] row : rows) {

            String assignmentType =
                    (String) row[0];

            String shuttleGroup =
                    (String) row[1];

            int buses =
                    ((Long) row[2]).intValue();

            long bookings =
                    (Long) row[3];

            if ("REGULAR".equals(assignmentType)) {

                regularBuses += buses;
                regularBookings += bookings;

            } else if ("VELACHERY".equals(shuttleGroup)) {

                velacheryBuses += buses;
                velacheryBookings += bookings;

            } else if ("ALANDUR_METRO".equals(shuttleGroup)) {

                alandurBuses += buses;
                alandurBookings += bookings;
            }
        }

        int regularCapacity =
                regularBuses * 55;

        int velacheryCapacity =
                velacheryBuses * 55;

        int alandurCapacity =
                alandurBuses * 55;

        long totalBookings =
                regularBookings +
                velacheryBookings +
                alandurBookings;

        int totalCapacity =
                regularCapacity +
                velacheryCapacity +
                alandurCapacity;

        return new AdminDashboardResponse(
                regularBuses,
                regularBookings,
                regularCapacity,
                totalBookings,
                totalCapacity,
                new AdminDashboardResponse.ShuttleOverview(
                        velacheryBuses,
                        velacheryBookings,
                        velacheryCapacity
                ),
                new AdminDashboardResponse.ShuttleOverview(
                        alandurBuses,
                        alandurBookings,
                        alandurCapacity
                )
        );
    }
}