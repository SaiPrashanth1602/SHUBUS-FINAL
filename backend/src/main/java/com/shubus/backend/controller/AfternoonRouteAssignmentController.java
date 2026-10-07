package com.shubus.backend.controller;

import java.time.LocalDate;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.shubus.backend.dto.AfternoonAssignmentRequest;
import com.shubus.backend.dto.AfternoonRouteAssignmentResponse;
import com.shubus.backend.model.AfternoonRouteAssignment;
import com.shubus.backend.model.Route;
import com.shubus.backend.repository.AfternoonRouteAssignmentRepository;
import com.shubus.backend.repository.RouteRepository;

@RestController
@RequestMapping("/api/admin/afternoon-routes")
public class AfternoonRouteAssignmentController {

    private final AfternoonRouteAssignmentRepository assignmentRepository;
    private final RouteRepository routeRepository;

    public AfternoonRouteAssignmentController(
            AfternoonRouteAssignmentRepository assignmentRepository,
            RouteRepository routeRepository) {
        this.assignmentRepository = assignmentRepository;
        this.routeRepository = routeRepository;
    }

    @GetMapping
    public List<AfternoonRouteAssignmentResponse> getAssignments(
            @RequestParam LocalDate date) {

        return assignmentRepository.findByAssignmentDate(date)
                .stream()
                .map(this::toResponse)
                .toList();
    }
@PostMapping("/bulk")
public ResponseEntity<List<AfternoonRouteAssignmentResponse>> createBulkAssignments(
        @RequestBody AfternoonAssignmentRequest request) {

    if (!request.assignmentType().equals("REGULAR")
            && !request.assignmentType().equals("SHUTTLE")) {
        return ResponseEntity.badRequest().build();
    }

    if (request.assignmentType().equals("SHUTTLE")
            && request.shuttleGroup() == null) {
        return ResponseEntity.badRequest().build();
    }

    if (request.assignmentType().equals("REGULAR")
            && request.shuttleGroup() != null) {
        return ResponseEntity.badRequest().build();
    }

    List<AfternoonRouteAssignmentResponse> responses =
            new java.util.ArrayList<>();

    for (Long routeId : request.routeIds()) {

        Route route = routeRepository.findById(routeId)
                .orElse(null);

        if (route == null) {
            return ResponseEntity.notFound().build();
        }

        AfternoonRouteAssignment assignment =
                new AfternoonRouteAssignment();

        assignment.setRoute(route);
        assignment.setAssignmentDate(request.date());
        assignment.setAssignmentType(request.assignmentType());
        assignment.setShuttleGroup(request.shuttleGroup());

        AfternoonRouteAssignment saved =
                assignmentRepository.save(assignment);

        responses.add(toResponse(saved));
    }

    return ResponseEntity.ok(responses);
}
    @PostMapping
    public ResponseEntity<AfternoonRouteAssignmentResponse> createAssignment(
            @RequestParam Long routeId,
            @RequestParam LocalDate date,
            @RequestParam String assignmentType,
            @RequestParam(required = false) String shuttleGroup) {

        if (!assignmentType.equals("REGULAR")
                && !assignmentType.equals("SHUTTLE")) {
            return ResponseEntity.badRequest().build();
        }

        if (assignmentType.equals("SHUTTLE")
                && shuttleGroup == null) {
            return ResponseEntity.badRequest().build();
        }

        if (assignmentType.equals("REGULAR")
                && shuttleGroup != null) {
            return ResponseEntity.badRequest().build();
        }

        Route route = routeRepository.findById(routeId)
                .orElse(null);

        if (route == null) {
            return ResponseEntity.notFound().build();
        }

        AfternoonRouteAssignment assignment =
                new AfternoonRouteAssignment();

        assignment.setRoute(route);
        assignment.setAssignmentDate(date);
        assignment.setAssignmentType(assignmentType);
        assignment.setShuttleGroup(shuttleGroup);

        AfternoonRouteAssignment saved =
                assignmentRepository.save(assignment);

        return ResponseEntity.ok(toResponse(saved));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAssignment(
            @PathVariable Long id) {

        if (!assignmentRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }

        assignmentRepository.deleteById(id);

        return ResponseEntity.noContent().build();
    }

    

    private AfternoonRouteAssignmentResponse toResponse(
            AfternoonRouteAssignment assignment) {

        Route route = assignment.getRoute();

        return new AfternoonRouteAssignmentResponse(
                assignment.getId(),
                route.getId(),
                route.getRouteNumber(),
                route.getRouteName(),
                route.getAcType(),
                assignment.getAssignmentDate(),
                assignment.getAssignmentType(),
                assignment.getShuttleGroup()
        );
    }
}