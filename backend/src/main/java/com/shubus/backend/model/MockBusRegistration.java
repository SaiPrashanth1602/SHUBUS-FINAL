package com.shubus.backend.model;

import jakarta.persistence.*;

@Entity
@Table(name = "mock_bus_registrations")
public class MockBusRegistration {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "reg_no", nullable = false, unique = true)
    private String regNo;

    @Column(name = "registered_bus_no", nullable = false)
    private Integer registeredBusNo;

    @Column(name = "route_name", nullable = false)
    private String routeName;

    @Column(name = "ac_type", nullable = false)
    private String acType;

    public Long getId() {
        return id;
    }

    public String getRegNo() {
        return regNo;
    }

    public void setRegNo(String regNo) {
        this.regNo = regNo;
    }

    public Integer getRegisteredBusNo() {
        return registeredBusNo;
    }

    public void setRegisteredBusNo(Integer registeredBusNo) {
        this.registeredBusNo = registeredBusNo;
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
}   