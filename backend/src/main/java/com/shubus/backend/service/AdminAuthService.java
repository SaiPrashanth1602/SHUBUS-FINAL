package com.shubus.backend.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.shubus.backend.dto.AdminLoginRequest;
import com.shubus.backend.model.AdminUser;
import com.shubus.backend.repository.AdminUserRepository;

@Service
public class AdminAuthService {

    private final AdminUserRepository adminUserRepository;
    private final PasswordEncoder passwordEncoder;

    public AdminAuthService(
            AdminUserRepository adminUserRepository,
            PasswordEncoder passwordEncoder
    ) {
        this.adminUserRepository = adminUserRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public AdminUser login(AdminLoginRequest request) {

        AdminUser admin = adminUserRepository
                .findByEmpId(request.empId())
                .orElseThrow(() ->
                        new RuntimeException("Invalid credentials"));

        if (!admin.getActive()) {
            throw new RuntimeException("Admin account is inactive");
        }

        if (!passwordEncoder.matches(
                request.password(),
                admin.getPasswordHash()
        )) {
            throw new RuntimeException("Invalid credentials");
        }

        return admin;
    }
}