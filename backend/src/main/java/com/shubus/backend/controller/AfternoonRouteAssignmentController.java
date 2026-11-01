package com.shubus.backend.controller;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
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
import com.shubus.backend.util.ShuttleSlotRules;

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
            @RequestParam(required = false) LocalDate date,
            @RequestParam(required = false) LocalDate endDate) {

        if (date == null && endDate == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "date is required");
        }

        if (date == null) {
            date = endDate;
        }

        if (endDate != null) {
            if (endDate.isBefore(date)) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "endDate cannot be before date");
            }
            return assignmentRepository.findByAssignmentDateBetween(date, endDate)
                    .stream()
                    .map(this::toResponse)
                    .toList();
        }

        return assignmentRepository.findByAssignmentDate(date)
                .stream()
                .map(this::toResponse)
                .toList();
    }

    /**
     * Saves a whole batch atomically. Existing assignments and the database's
     * (assignment_date, route_id) uniqueness rule are checked before writing.
     */
    @Transactional
    @PostMapping("/bulk")
    public ResponseEntity<?> createBulkAssignments(
            @RequestBody AfternoonAssignmentRequest request) {

        String validationError = validateRequest(
                request == null ? null : request.date(),
                request == null ? null : request.routeIds(),
                request == null ? null : request.assignmentType(),
                request == null ? null : request.shuttleGroup());

        if (validationError != null) {
            return ResponseEntity.badRequest().body(java.util.Map.of("error", validationError));
        }

        List<Long> routeIds = request.routeIds();
        if (new HashSet<>(routeIds).size() != routeIds.size()) {
            return ResponseEntity.badRequest().body(
                    java.util.Map.of("error", "routeIds contains duplicates"));
        }

        List<Route> routes = new ArrayList<>();
        for (Long routeId : routeIds) {
            if (routeId == null) {
                return ResponseEntity.badRequest().body(
                        java.util.Map.of("error", "routeIds cannot contain null"));
            }
            Route route = routeRepository.findById(routeId).orElse(null);
            if (route == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(
                        java.util.Map.of("error", "Route not found: " + routeId));
            }
            if (assignmentRepository.existsByAssignmentDateAndRoute_Id(
                    request.date(), routeId)) {
                return ResponseEntity.status(HttpStatus.CONFLICT).body(
                        java.util.Map.of("error", "Route " + routeId +
                                " is already assigned for " + request.date()));
            }
            routes.add(route);
        }

        List<AfternoonRouteAssignmentResponse> responses = new ArrayList<>();
        for (Route route : routes) {
            AfternoonRouteAssignment assignment = new AfternoonRouteAssignment();
            assignment.setRoute(route);
            assignment.setAssignmentDate(request.date());
            assignment.setAssignmentType(normalizeType(request.assignmentType()));
            assignment.setShuttleGroup(normalizeGroup(request.shuttleGroup()));
            responses.add(toResponse(assignmentRepository.save(assignment)));
        }

        return ResponseEntity.ok(responses);
    }

    @Transactional
    @PostMapping
    public ResponseEntity<?> createAssignment(
            @RequestParam Long routeId,
            @RequestParam LocalDate date,
            @RequestParam String assignmentType,
            @RequestParam(required = false) String shuttleGroup) {

        String validationError = validateRequest(
                date, List.of(routeId), assignmentType, shuttleGroup);
        if (validationError != null) {
            return ResponseEntity.badRequest().body(
                    java.util.Map.of("error", validationError));
        }

        Route route = routeRepository.findById(routeId).orElse(null);
        if (route == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(
                    java.util.Map.of("error", "Route not found: " + routeId));
        }

        if (assignmentRepository.existsByAssignmentDateAndRoute_Id(date, routeId)) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body(
                    java.util.Map.of("error", "Route is already assigned for " + date));
        }

        AfternoonRouteAssignment assignment = new AfternoonRouteAssignment();
        assignment.setRoute(route);
        assignment.setAssignmentDate(date);
        assignment.setAssignmentType(normalizeType(assignmentType));
        assignment.setShuttleGroup(normalizeGroup(shuttleGroup));

        return ResponseEntity.ok(toResponse(assignmentRepository.save(assignment)));
    }

    @Transactional
    @PutMapping("/{id}")
    public ResponseEntity<?> updateAssignment(
            @PathVariable Long id,
            @RequestParam String assignmentType,
            @RequestParam(required = false) String shuttleGroup) {

        AfternoonRouteAssignment assignment = assignmentRepository.findById(id).orElse(null);
        if (assignment == null) {
            return ResponseEntity.notFound().build();
        }

        String validationError = validateRequest(
                assignment.getAssignmentDate(),
                List.of(assignment.getRoute().getId()),
                assignmentType,
                shuttleGroup);
        if (validationError != null) {
            return ResponseEntity.badRequest().body(java.util.Map.of("error", validationError));
        }

        assignment.setAssignmentType(normalizeType(assignmentType));
        assignment.setShuttleGroup(normalizeGroup(shuttleGroup));
        return ResponseEntity.ok(toResponse(assignmentRepository.save(assignment)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAssignment(@PathVariable Long id) {
        if (!assignmentRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        assignmentRepository.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    private String validateRequest(
            LocalDate date, List<Long> routeIds, String assignmentType, String shuttleGroup) {
        if (date == null) return "date is required";
        if (routeIds == null || routeIds.isEmpty()) return "At least one routeId is required";
        if (assignmentType == null) return "assignmentType is required";

        String type = assignmentType.trim().toUpperCase(Locale.ROOT);
        if (!type.equals("REGULAR") && !type.equals("SHUTTLE")) {
            return "assignmentType must be REGULAR or SHUTTLE";
        }

        if (type.equals("REGULAR") && shuttleGroup != null && !shuttleGroup.isBlank()) {
            return "REGULAR assignments cannot have a shuttleGroup";
        }
        if (type.equals("SHUTTLE")) {
            if (shuttleGroup == null || shuttleGroup.isBlank()) {
                return "SHUTTLE assignments require a shuttleGroup or slot";
            }
            if (!ShuttleSlotRules.isSupported(shuttleGroup)) {
                return "Unsupported shuttle group/slot: " + shuttleGroup;
            }
        }
        return null;
    }

    private String normalizeType(String assignmentType) {
        return assignmentType.trim().toUpperCase(Locale.ROOT);
    }

    private String normalizeGroup(String shuttleGroup) {
        if (shuttleGroup == null || shuttleGroup.isBlank()) return null;
        return shuttleGroup.trim().toUpperCase(Locale.ROOT);
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
