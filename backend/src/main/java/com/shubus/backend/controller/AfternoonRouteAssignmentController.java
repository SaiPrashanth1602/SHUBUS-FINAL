package com.shubus.backend.controller;


import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;


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


        String shuttleGroup = normalizeGroup(request.shuttleGroup());


        if ("SHUTTLE".equals(normalizeType(request.assignmentType()))) {
            String slotError = validateAdminShuttleCreation(
                    request.date(),
                    shuttleGroup
            );


            if (slotError != null) {
                return ResponseEntity.badRequest().body(
                        java.util.Map.of("error", slotError)
                );
            }
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


            if ("SHUTTLE".equals(normalizeType(request.assignmentType()))) {
                String acError = validateShuttleAcType(route, shuttleGroup);


                if (acError != null) {
                    return ResponseEntity.badRequest().body(
                            java.util.Map.of("error", acError));
                }
            }


            routes.add(route);
        }


        List<AfternoonRouteAssignmentResponse> responses = new ArrayList<>();


        for (Route route : routes) {
            AfternoonRouteAssignment assignment = new AfternoonRouteAssignment();
            assignment.setRoute(route);
            assignment.setAssignmentDate(request.date());
            assignment.setAssignmentType(normalizeType(request.assignmentType()));
            assignment.setShuttleGroup(shuttleGroup);
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


        String normalizedGroup = normalizeGroup(shuttleGroup);


        if ("SHUTTLE".equals(normalizeType(assignmentType))) {
            String slotError = validateAdminShuttleCreation(
                    date,
                    normalizedGroup
            );


            if (slotError != null) {
                return ResponseEntity.badRequest().body(
                        java.util.Map.of("error", slotError)
                );
            }


            String acError = validateShuttleAcType(route, normalizedGroup);


            if (acError != null) {
                return ResponseEntity.badRequest().body(
                        java.util.Map.of("error", acError));
            }
        }


        AfternoonRouteAssignment assignment = new AfternoonRouteAssignment();
        assignment.setRoute(route);
        assignment.setAssignmentDate(date);
        assignment.setAssignmentType(normalizeType(assignmentType));
        assignment.setShuttleGroup(normalizedGroup);


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


        String normalizedGroup = normalizeGroup(shuttleGroup);


        if ("SHUTTLE".equals(normalizeType(assignmentType))) {
            String acError = validateShuttleAcType(
                    assignment.getRoute(),
                    normalizedGroup
            );


            if (acError != null) {
                return ResponseEntity.badRequest().body(
                        java.util.Map.of("error", acError));
            }
        }


        assignment.setAssignmentType(normalizeType(assignmentType));
        assignment.setShuttleGroup(normalizedGroup);


        return ResponseEntity.ok(toResponse(assignmentRepository.save(assignment)));
    }


    @Transactional
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAssignment(@PathVariable Long id) {
        AfternoonRouteAssignment assignment = assignmentRepository.findById(id).orElse(null);


        if (assignment == null) {
            return ResponseEntity.notFound().build();
        }


        LocalDate date = assignment.getAssignmentDate();
        String assignmentType = assignment.getAssignmentType();


        assignmentRepository.delete(assignment);


        if ("SHUTTLE".equals(assignmentType)) {
            compactShuttleSlots(date);
        }


        return ResponseEntity.noContent().build();
    }


    private String validateRequest(
            LocalDate date,
            List<Long> routeIds,
            String assignmentType,
            String shuttleGroup) {


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


    private String validateShuttleAcType(Route route, String shuttleGroup) {
        String requiredAcType = ShuttleSlotRules.allowedAcType(shuttleGroup);


        if (requiredAcType == null) {
            return null;
        }


        String routeAcType = normalizeAcType(route.getAcType());


        if (!routeAcType.equals(requiredAcType)) {
            return getDestinationLabel(shuttleGroup) +
                    " shuttle slots accept " + requiredAcType +
                    " buses only. Selected bus is " + routeAcType + ".";
        }


        return null;
    }


    private String normalizeAcType(String acType) {
        if (acType == null || acType.isBlank()) {
            return "UNKNOWN";
        }


        String value = acType.trim().toUpperCase(Locale.ROOT);


        if (value.contains("NON")) {
            return "NON-AC";
        }


        if (value.contains("AC")) {
            return "AC";
        }


        return value;
    }


    private String getDestinationLabel(String shuttleGroup) {
        return switch (ShuttleSlotRules.slotPrefix(shuttleGroup)) {
            case "A" -> "Alandur Metro";
            case "V" -> "Velachery";
            case "S" -> "Sholinganallur";
            case "T" -> "Tambaram";
            default -> "This";
        };
    }


    private String validateAdminShuttleCreation(
            LocalDate date,
            String shuttleGroup
    ) {
        if (shuttleGroup == null || shuttleGroup.isBlank()) {
            return "SHUTTLE assignments require a shuttleGroup or slot";
        }


        String slot = shuttleGroup.trim().toUpperCase(Locale.ROOT);


        Set<String> existingSlots = assignmentRepository
                .findByAssignmentDate(date)
                .stream()
                .filter(a -> "SHUTTLE".equals(a.getAssignmentType()))
                .map(a -> a.getShuttleGroup())
                .filter(value -> value != null && !value.isBlank())
                .map(value -> value.trim().toUpperCase(Locale.ROOT))
                .collect(java.util.stream.Collectors.toSet());


        if (existingSlots.contains(slot)) {
            return "Shuttle slot " + slot + " is already assigned for " + date;
        }


        for (String previousSlot : ShuttleSlotRules.requiredPreviousSlots(slot)) {
            if (!existingSlots.contains(previousSlot)) {
                return "Shuttle slot " + previousSlot +
                        " must be assigned before " + slot;
            }
        }


        return null;
    }


    private void compactShuttleSlots(LocalDate date) {
        List<AfternoonRouteAssignment> assignments =
                assignmentRepository.findByAssignmentDate(date);


        List<String> prefixes = List.of("A", "V", "S", "T");


        for (String prefix : prefixes) {
            List<AfternoonRouteAssignment> shuttleAssignments = assignments
                    .stream()
                    .filter(a -> "SHUTTLE".equals(a.getAssignmentType()))
                    .filter(a -> a.getShuttleGroup() != null)
                    .filter(a -> ShuttleSlotRules.slotPrefix(a.getShuttleGroup()) != null)
                    .filter(a -> ShuttleSlotRules.slotPrefix(a.getShuttleGroup()).equals(prefix))
                    .sorted((a, b) -> Integer.compare(
                            ShuttleSlotRules.slotNumber(a.getShuttleGroup()),
                            ShuttleSlotRules.slotNumber(b.getShuttleGroup())
                    ))
                    .toList();


            for (int i = 0; i < shuttleAssignments.size(); i++) {
                AfternoonRouteAssignment assignment = shuttleAssignments.get(i);
                String targetSlot = prefix + (i + 1);
                String currentSlot = assignment.getShuttleGroup()
                        .trim()
                        .toUpperCase(Locale.ROOT);


                if (!currentSlot.equals(targetSlot)) {
                    assignment.setShuttleGroup(targetSlot);
                    assignmentRepository.save(assignment);
                }
            }
        }
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