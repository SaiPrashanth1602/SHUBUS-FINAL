package com.shubus.backend.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import com.shubus.backend.dto.BusRegistrationResponse;
import com.shubus.backend.model.MockBusRegistration;
import com.shubus.backend.repository.MockBusRegistrationRepository;

@RestController
@RequestMapping("/api/registrations")
public class BusRegistrationController {

    private final MockBusRegistrationRepository registrationRepository;

    public BusRegistrationController(
            MockBusRegistrationRepository registrationRepository) {
        this.registrationRepository = registrationRepository;
    }

    @GetMapping("/{regNo}")
    public BusRegistrationResponse getRegistration(
            @PathVariable String regNo) {

        MockBusRegistration registration =
                registrationRepository.findByRegNo(regNo)
                        .orElseThrow(() ->
                                new ResponseStatusException(
                                        HttpStatus.NOT_FOUND,
                                        "Registration not found"));

        return new BusRegistrationResponse(
                registration.getRegNo(),
                registration.getRegisteredBusNo(),
                registration.getRouteName(),
                registration.getAcType()
        );
    }
}