package com.shubus.backend.repository;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.shubus.backend.model.AfternoonRouteAssignment;

public interface AdminDashboardRepository
        extends JpaRepository<AfternoonRouteAssignment, Long> {

    @Query("""
        SELECT
            a.assignmentType,
            a.shuttleGroup,
            COUNT(DISTINCT a.id),
            COUNT(b.id)
        FROM AfternoonRouteAssignment a
        LEFT JOIN Booking b
            ON b.afternoonAssignment.id = a.id
            AND b.bookingDate = a.assignmentDate
        WHERE a.assignmentDate = :date
        GROUP BY a.assignmentType, a.shuttleGroup
        """)
    List<Object[]> getOverview(LocalDate date);
}