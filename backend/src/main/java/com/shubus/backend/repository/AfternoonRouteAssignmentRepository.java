package com.shubus.backend.repository;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.shubus.backend.model.AfternoonRouteAssignment;

public interface AfternoonRouteAssignmentRepository
        extends JpaRepository<AfternoonRouteAssignment, Long> {

    List<AfternoonRouteAssignment> findByAssignmentDate(
            LocalDate assignmentDate
    );

    List<AfternoonRouteAssignment> findByAssignmentDateBetween(
            LocalDate startDate,
            LocalDate endDate
    );

    boolean existsByAssignmentDateAndRoute_Id(
            LocalDate assignmentDate, Long routeId
    );

    boolean existsByRoute_Id(Long routeId);
}
