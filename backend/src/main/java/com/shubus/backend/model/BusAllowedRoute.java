package com.shubus.backend.model;

import jakarta.persistence.*;

@Entity
@Table(name = "bus_allowed_routes")
public class BusAllowedRoute {

    @EmbeddedId
    private BusAllowedRouteId id;

    public BusAllowedRouteId getId() {
        return id;
    }

    public void setId(BusAllowedRouteId id) {
        this.id = id;
    }
}