package com.shubus.backend.repository;

import com.shubus.backend.model.Bus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface BusRepository extends JpaRepository<Bus, Long> {

    Optional<Bus> findByBusNumber(Integer busNumber);

    List<Bus> findByActiveTrue();

    List<Bus> findByAcTypeAndActiveTrue(String acType);

    List<Bus> findByIdInAndActiveTrue(List<Long> ids);
}