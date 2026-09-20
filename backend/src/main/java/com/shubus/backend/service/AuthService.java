package com.shubus.backend.service;

import com.shubus.backend.dto.LoginRequest;
import com.shubus.backend.dto.LoginResponse;
import com.shubus.backend.model.Student;
import com.shubus.backend.repository.StudentRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private final StudentRepository studentRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthService(
            StudentRepository studentRepository,
            PasswordEncoder passwordEncoder) {

        this.studentRepository = studentRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public LoginResponse login(LoginRequest request) {

        Student student = studentRepository
                .findByRegNo(request.regNo())
                .orElseThrow(() -> new RuntimeException("Invalid credentials"));

        if (!student.getActive()) {
            throw new RuntimeException("Student account is inactive");
        }

        if (!passwordEncoder.matches(
                request.password(),
                student.getPasswordHash())) {

            throw new RuntimeException("Invalid credentials");
        }

        return new LoginResponse(
                student.getRegNo(),
                student.getName(),
                student.getActive(),
                "Login successful"
        );
    }
}