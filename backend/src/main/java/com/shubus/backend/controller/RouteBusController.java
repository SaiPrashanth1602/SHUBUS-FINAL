package com.shubus.backend.controller;

import com.shubus.backend.model.Bus;
import com.shubus.backend.repository.BusAllowedRouteRepository;
import com.shubus.backend.repository.BusRepository;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/routes")
public class RouteBusController {

    private final BusAllowedRouteRepository mappingRepository;
    private final BusRepository busRepository;

    public RouteBusController(
            BusAllowedRouteRepository mappingRepository,
            BusRepository busRepository) {
        this.mappingRepository = mappingRepository;
        this.busRepository = busRepository;
    }

    @GetMapping("/{routeId}/buses")
    public List<Bus> getBusesForRoute(
            @PathVariable Long routeId) {

        List<Long> busIds = mappingRepository
                .findByIdRouteId(routeId)
                .stream()
                .map(mapping -> mapping.getId().getBusId())
                .toList();

        return busRepository.findByIdInAndActiveTrue(busIds);
    }
}