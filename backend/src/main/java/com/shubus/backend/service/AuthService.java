package com.shubus.backend.service;

import com.shubus.backend.dto.LoginRequest;
import com.shubus.backend.dto.LoginResponse;
import com.shubus.backend.model.Student;
import com.shubus.backend.repository.StudentRepository;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private final StudentRepository studentRepository;

    public AuthService(StudentRepository studentRepository) {
        this.studentRepository = studentRepository;
    }

    /**
     * Registration-number-only sign-in for the requested prototype flow.
     * This identifies a student but does not securely authenticate them.
     */
    public LoginResponse login(LoginRequest request) {
        if (request == null || request.regNo() == null || request.regNo().isBlank()) {
            throw new RuntimeException("Registration number is required");
        }

        String regNo = request.regNo().trim().toUpperCase();
        Student student = studentRepository
                .findByRegNo(regNo)
                .orElseThrow(() -> new RuntimeException("Student not found"));

        if (!Boolean.TRUE.equals(student.getActive())) {
            throw new RuntimeException("Student account is inactive");
        }

        return new LoginResponse(
                student.getRegNo(),
                student.getName(),
                student.getActive(),
                "Sign in successful"
        );
    }
}
