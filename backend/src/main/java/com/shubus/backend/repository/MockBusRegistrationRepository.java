package com.shubus.backend.repository;

import com.shubus.backend.model.MockBusRegistration;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MockBusRegistrationRepository
        extends JpaRepository<MockBusRegistration, Long> {

    Optional<MockBusRegistration> findByRegNo(String regNo);
}