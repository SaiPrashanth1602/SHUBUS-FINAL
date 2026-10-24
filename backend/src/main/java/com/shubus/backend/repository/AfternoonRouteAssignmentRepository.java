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

    boolean existsByAssignmentDateAndRoute_Id(
            LocalDate assignmentDate, Long routeId
    );
}
