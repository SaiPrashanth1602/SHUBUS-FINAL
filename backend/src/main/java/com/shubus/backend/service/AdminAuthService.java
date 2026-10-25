package com.shubus.backend.service;

import org.springframework.stereotype.Service;

import com.shubus.backend.dto.AdminLoginRequest;
import com.shubus.backend.model.AdminUser;
import com.shubus.backend.repository.AdminUserRepository;

@Service
public class AdminAuthService {

    private final AdminUserRepository adminUserRepository;

    public AdminAuthService(AdminUserRepository adminUserRepository) {
        this.adminUserRepository = adminUserRepository;
    }

    public AdminUser login(AdminLoginRequest request) {
        if (request == null || request.empId() == null || request.empId().isBlank()) {
            throw new RuntimeException("Employee ID is required");
        }

        AdminUser admin = adminUserRepository
                .findByEmpId(request.empId().trim())
                .orElseThrow(() -> new RuntimeException("Employee ID not found"));

        if (!Boolean.TRUE.equals(admin.getActive())) {
            throw new RuntimeException("Admin account is inactive");
        }

        return admin;
    }
}
