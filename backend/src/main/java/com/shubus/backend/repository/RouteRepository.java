package com.shubus.backend.repository;

import com.shubus.backend.model.Route;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface RouteRepository extends JpaRepository<Route, Long> {

    Optional<Route> findByName(String name);

    List<Route> findByActiveTrue();
}