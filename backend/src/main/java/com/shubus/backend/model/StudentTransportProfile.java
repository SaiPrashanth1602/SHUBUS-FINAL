package com.shubus.backend.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "student_transport_profiles")
public class StudentTransportProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "student_id", nullable = false, unique = true)
    private Long studentId;

    @Column(name = "morning_route_number", nullable = false)
    private String morningRouteNumber;

    @Column(name = "morning_route_name", nullable = false)
    private String morningRouteName;

    @Column(name = "ac_type", nullable = false)
    private String acType;

    public StudentTransportProfile() {
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getStudentId() {
        return studentId;
    }

    public void setStudentId(Long studentId) {
        this.studentId = studentId;
    }

    public String getMorningRouteNumber() {
        return morningRouteNumber;
    }

    public void setMorningRouteNumber(String morningRouteNumber) {
        this.morningRouteNumber = morningRouteNumber;
    }

    public String getMorningRouteName() {
        return morningRouteName;
    }

    public void setMorningRouteName(String morningRouteName) {
        this.morningRouteName = morningRouteName;
    }

    public String getAcType() {
        return acType;
    }

    public void setAcType(String acType) {
        this.acType = acType;
    }
}