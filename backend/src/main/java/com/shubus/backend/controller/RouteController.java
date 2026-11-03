package com.shubus.backend.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.shubus.backend.dto.RouteResponse;
import com.shubus.backend.model.Route;
import com.shubus.backend.repository.AfternoonRouteAssignmentRepository;
import com.shubus.backend.repository.RouteRepository;

@RestController
@RequestMapping("/api/admin/routes")
public class RouteController {

    private final RouteRepository routeRepository;
    private final AfternoonRouteAssignmentRepository assignmentRepository;

    public RouteController(
            RouteRepository routeRepository,
            AfternoonRouteAssignmentRepository assignmentRepository) {
        this.routeRepository = routeRepository;
        this.assignmentRepository = assignmentRepository;
    }

    @GetMapping
    public List<RouteResponse> getAllRoutes() {
        return routeRepository.findAll()
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @GetMapping("/{id}")
    public ResponseEntity<RouteResponse> getRoute(@PathVariable Long id) {
        return routeRepository.findById(id)
                .map(route -> ResponseEntity.ok(toResponse(route)))
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<RouteResponse> createRoute(@RequestBody Route route) {
        if (route == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Route details are required");
        }
        requireValue(route.getRouteNumber(), "routeNumber");
        requireValue(route.getRouteCode(), "routeCode");
        requireValue(route.getRouteName(), "routeName");
        requireValue(route.getAcType(), "acType");
        if (route.getAllowedRoutes() == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "allowedRoutes is required");
        }
        if (routeRepository.existsByRouteNumberIgnoreCase(
                route.getRouteNumber().trim())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Route number already exists");
        }
        if (routeRepository.existsByRouteCodeIgnoreCase(
                route.getRouteCode().trim())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Route code already exists");
        }

        route.setRouteNumber(route.getRouteNumber().trim());
        route.setRouteCode(route.getRouteCode().trim());
        Route savedRoute = routeRepository.save(route);

        return ResponseEntity.ok(toResponse(savedRoute));
    }

    @PutMapping("/{id}")
    public ResponseEntity<RouteResponse> updateRoute(
            @PathVariable Long id,
            @RequestBody Route updatedRoute) {

        if (updatedRoute == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Route details are required");
        }

        return routeRepository.findById(id)
                .map(route -> {
                    String routeNumber = updatedRoute.getRouteNumber();
                    if (routeNumber != null) {
                        requireValue(routeNumber, "routeNumber");
                        routeNumber = routeNumber.trim();
                        if (routeRepository
                                .existsByRouteNumberIgnoreCaseAndIdNot(
                                        routeNumber, id)) {
                            throw new ResponseStatusException(
                                    HttpStatus.CONFLICT,
                                    "Route number already exists");
                        }
                    }

                    String routeCode = updatedRoute.getRouteCode();
                    if (routeCode != null) {
                        requireValue(routeCode, "routeCode");
                        routeCode = routeCode.trim();
                        if (routeRepository
                                .existsByRouteCodeIgnoreCaseAndIdNot(
                                        routeCode, id)) {
                            throw new ResponseStatusException(
                                    HttpStatus.CONFLICT,
                                    "Route code already exists");
                        }
                    }

                    if (updatedRoute.getRouteName() != null) {
                        requireValue(updatedRoute.getRouteName(), "routeName");
                    }
                    if (updatedRoute.getAcType() != null) {
                        requireValue(updatedRoute.getAcType(), "acType");
                    }

                    if (routeNumber != null) {
                        route.setRouteNumber(routeNumber);
                    }
                    if (routeCode != null) {
                        route.setRouteCode(routeCode);
                    }
                    if (updatedRoute.getRouteName() != null) {
                        route.setRouteName(updatedRoute.getRouteName().trim());
                    }
                    if (updatedRoute.getAcType() != null) {
                        route.setAcType(updatedRoute.getAcType().trim());
                    }
                    if (updatedRoute.getAllowedRoutes() != null) {
                        route.setAllowedRoutes(updatedRoute.getAllowedRoutes());
                    }

                    Route savedRoute = routeRepository.save(route);

                    return ResponseEntity.ok(toResponse(savedRoute));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteRoute(@PathVariable Long id) {

        Route route = routeRepository.findById(id).orElse(null);
        if (route == null) {
            return ResponseEntity.notFound().build();
        }

        if (assignmentRepository.existsByRoute_Id(id)) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body(
                    java.util.Map.of(
                            "error",
                            "Cannot delete route " + route.getRouteNumber()
                                    + " because it has assigned buses. Remove its assignments first."));
        }

        routeRepository.deleteById(id);

        return ResponseEntity.noContent().build();
    }

    private RouteResponse toResponse(Route route) {

        return new RouteResponse(
        route.getId(),
        route.getRouteNumber(),
        route.getRouteCode(),
        route.getRouteName(),
        route.getAcType(),
        route.getAllowedRoutes(),
        route.isDefaultAfternoon()
);
    }

    private void requireValue(String value, String field) {
        if (value == null || value.isBlank()) {
            String label = switch (field) {
                case "routeNumber" -> "Route number";
                case "routeCode" -> "Route code";
                case "routeName" -> "Route name";
                case "acType" -> "Bus type";
                case "allowedRoutes" -> "Allowed afternoon routes";
                default -> "This field";
            };
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, label + " is required");
        }
    }
}