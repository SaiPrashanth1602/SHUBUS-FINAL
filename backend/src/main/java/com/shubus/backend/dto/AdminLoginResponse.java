package com.shubus.backend.dto;

public record AdminLoginResponse(
        String empId,
        Boolean active,
        String message
) {}