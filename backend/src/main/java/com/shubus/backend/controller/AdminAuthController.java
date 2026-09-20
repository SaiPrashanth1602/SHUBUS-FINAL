package com.shubus.backend.controller;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.shubus.backend.dto.AdminLoginRequest;
import com.shubus.backend.dto.AdminLoginResponse;
import com.shubus.backend.model.AdminUser;
import com.shubus.backend.service.AdminAuthService;

@RestController
@RequestMapping("/api/admin/auth")
public class AdminAuthController {

    private final AdminAuthService adminAuthService;

    public AdminAuthController(AdminAuthService adminAuthService) {
        this.adminAuthService = adminAuthService;
    }

    @PostMapping("/login")
    public AdminLoginResponse login(
            @RequestBody AdminLoginRequest request
    ) {
        AdminUser admin = adminAuthService.login(request);

        return new AdminLoginResponse(
                admin.getEmpId(),
                admin.getActive(),
                "Admin login successful"
        );
    }
}