package com.shubus.backend.repository;

import com.shubus.backend.model.BusAllowedRoute;
import com.shubus.backend.model.BusAllowedRouteId;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BusAllowedRouteRepository
        extends JpaRepository<BusAllowedRoute, BusAllowedRouteId> {

    List<BusAllowedRoute> findByIdRouteId(Long routeId);

    List<BusAllowedRoute> findByIdBusId(Long busId);
}