package com.shubus.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.shubus.backend.model.StudentTransportProfile;

public interface StudentTransportProfileRepository
        extends JpaRepository<StudentTransportProfile, Long> {

    Optional<StudentTransportProfile> findByStudentId(Long studentId);

    Optional<StudentTransportProfile> findByStudentIdAndActiveTrue(Long studentId);
}