package com.shubus.backend.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "routes")
public class Route {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "route_number", nullable = false, unique = true)
    private String routeNumber;

    @Column(name = "route_code", nullable = false, unique = true)
    private String routeCode;

    @Column(name = "route_name", nullable = false)
    private String routeName;

    @Column(name = "ac_type", nullable = false)
    private String acType;

    @Column(name = "allowed_routes", nullable = false)
    private String[] allowedRoutes;

    @Column(name = "default_afternoon", nullable = false)
    private boolean defaultAfternoon;

    public Long getId() {
        return id;
    }

    public String getRouteNumber() {
        return routeNumber;
    }

    public void setRouteNumber(String routeNumber) {
        this.routeNumber = routeNumber;
    }

    public String getRouteCode() {
        return routeCode;
    }

    public void setRouteCode(String routeCode) {
        this.routeCode = routeCode;
    }

    public String getRouteName() {
        return routeName;
    }

    public void setRouteName(String routeName) {
        this.routeName = routeName;
    }

    public String getAcType() {
        return acType;
    }

    public void setAcType(String acType) {
        this.acType = acType;
    }

    public String[] getAllowedRoutes() {
        return allowedRoutes;
    }

    public void setAllowedRoutes(String[] allowedRoutes) {
        this.allowedRoutes = allowedRoutes;
    }

    public boolean isDefaultAfternoon() {
        return defaultAfternoon;
    }

    public void setDefaultAfternoon(boolean defaultAfternoon) {
        this.defaultAfternoon = defaultAfternoon;
    }
}
