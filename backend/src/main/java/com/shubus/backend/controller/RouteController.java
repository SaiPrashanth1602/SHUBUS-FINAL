package com.shubus.backend.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.shubus.backend.dto.RouteResponse;
import com.shubus.backend.model.Route;
import com.shubus.backend.repository.RouteRepository;

@RestController
@RequestMapping("/api/admin/routes")
public class RouteController {

    private final RouteRepository routeRepository;

    public RouteController(RouteRepository routeRepository) {
        this.routeRepository = routeRepository;
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

        if (routeRepository.existsByRouteNumber(route.getRouteNumber())) {
            return ResponseEntity.badRequest().build();
        }

        Route savedRoute = routeRepository.save(route);

        return ResponseEntity.ok(toResponse(savedRoute));
    }

    @PutMapping("/{id}")
    public ResponseEntity<RouteResponse> updateRoute(
            @PathVariable Long id,
            @RequestBody Route updatedRoute) {

        return routeRepository.findById(id)
                .map(route -> {

                    route.setRouteNumber(updatedRoute.getRouteNumber());
                    route.setRouteName(updatedRoute.getRouteName());
                    route.setAcType(updatedRoute.getAcType());
                    route.setAllowedRoutes(updatedRoute.getAllowedRoutes());

                    Route savedRoute = routeRepository.save(route);

                    return ResponseEntity.ok(toResponse(savedRoute));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteRoute(@PathVariable Long id) {

        if (!routeRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }

        routeRepository.deleteById(id);

        return ResponseEntity.noContent().build();
    }

    private RouteResponse toResponse(Route route) {

        return new RouteResponse(
        route.getId(),
        route.getRouteNumber(),
        route.getRouteName(),
        route.getAcType(),
        route.getAllowedRoutes(),
        route.isDefaultAfternoon()
);
    }
}