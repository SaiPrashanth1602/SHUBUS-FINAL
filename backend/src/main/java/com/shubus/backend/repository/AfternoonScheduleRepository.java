package com.shubus.backend.repository;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.shubus.backend.model.AfternoonRouteAssignment;
    
public interface AfternoonScheduleRepository
        extends JpaRepository<AfternoonRouteAssignment, Long> {

    @Query("""
        SELECT
            a.id,
            r.id,
            r.routeNumber,
            r.routeName,
            r.acType,
            a.assignmentType,
            a.shuttleGroup,
            a.assignmentDate,
            COUNT(b.id)
        FROM AfternoonRouteAssignment a
        JOIN a.route r
        LEFT JOIN Booking b
            ON b.afternoonAssignment.id = a.id
            AND b.bookingDate = a.assignmentDate
        WHERE a.assignmentDate = :date
        GROUP BY
            a.id,
            r.id,
            r.routeNumber,
            r.routeName,
            r.acType,
            a.assignmentType,
            a.shuttleGroup,
            a.assignmentDate
        ORDER BY a.assignmentType, r.routeNumber
        """)
    List<Object[]> getSchedule(LocalDate date);

    @Query("""
 SELECT
   a.id, r.id, r.routeNumber, r.routeName, r.acType,
   a.assignmentType, a.shuttleGroup, a.assignmentDate, COUNT(b.id)
 FROM AfternoonRouteAssignment a
 JOIN a.route r
 LEFT JOIN Booking b
   ON b.afternoonAssignment.id = a.id
   AND b.bookingDate = a.assignmentDate
 WHERE a.assignmentDate = :date
 GROUP BY a.id, r.id, r.routeNumber, r.routeName, r.acType,
          a.assignmentType, a.shuttleGroup, a.assignmentDate
 ORDER BY a.assignmentType, r.routeNumber
 """)
List<Object[]> getStudentSchedule(LocalDate date);
}