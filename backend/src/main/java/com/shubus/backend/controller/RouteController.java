package com.shubus.backend.controller;

import com.shubus.backend.dto.RouteResponse;
import com.shubus.backend.model.Route;
import com.shubus.backend.repository.RouteRepository;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/routes")
public class RouteController {

    private final RouteRepository routeRepository;

    public RouteController(RouteRepository routeRepository) {
        this.routeRepository = routeRepository;
    }

    @GetMapping
    public List<RouteResponse> getActiveRoutes() {

        return routeRepository.findByActiveTrue()
                .stream()
                .map(route -> new RouteResponse(
                        route.getId(),
                        route.getName(),
                        route.getRouteType(),
                        route.getActive()
                ))
                .toList();
    }
}