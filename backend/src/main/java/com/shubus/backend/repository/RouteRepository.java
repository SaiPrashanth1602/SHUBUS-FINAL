package com.shubus.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.shubus.backend.model.Route;

public interface RouteRepository extends JpaRepository<Route, Long> {

    Optional<Route> findByRouteNumber(String routeNumber);

    boolean existsByRouteNumber(String routeNumber);

    boolean existsByRouteNumberIgnoreCase(String routeNumber);

    boolean existsByRouteNumberIgnoreCaseAndIdNot(
            String routeNumber, Long id);

    boolean existsByRouteCodeIgnoreCase(String routeCode);

    boolean existsByRouteCodeIgnoreCaseAndIdNot(
            String routeCode, Long id);
}