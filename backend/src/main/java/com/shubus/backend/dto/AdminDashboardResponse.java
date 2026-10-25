package com.shubus.backend.dto;

public record AdminDashboardResponse(
        int regularBuses,
        long regularBookings,
        int regularCapacity,

        long totalBookings,
        int totalCapacity,

        ShuttleOverview velachery,
        ShuttleOverview alandurMetro,
        ShuttleOverview sholinganallur,
        ShuttleOverview tambaram
) {

    public record ShuttleOverview(
            int buses,
            long bookings,
            int capacity
    ) {}
}
