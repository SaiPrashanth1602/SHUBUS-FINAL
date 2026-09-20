package com.shubus.backend.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.shubus.backend.dto.BusResponse;
import com.shubus.backend.model.Bus;
import com.shubus.backend.repository.BusRepository;

@RestController
@RequestMapping("/api/buses")
public class BusController {

    private final BusRepository busRepository;

    public BusController(BusRepository busRepository) {
        this.busRepository = busRepository;
    }

    @GetMapping
    public List<BusResponse> getActiveBuses(
            @RequestParam(required = false) String acType) {

        List<Bus> buses;

        if (acType != null) {
            buses = busRepository.findByAcTypeAndActiveTrue(acType);
        } else {
            buses = busRepository.findByActiveTrue();
        }

        return buses.stream()
                .map(bus -> new BusResponse(
                        bus.getBusNumber(),
                        bus.getRouteName(),
                        bus.getNumberPlate(),
                        bus.getBusType(),
                        bus.getAcType(),
                        bus.getSeatCapacity(),
                        bus.getActive()
                ))
                .toList();
    }
}