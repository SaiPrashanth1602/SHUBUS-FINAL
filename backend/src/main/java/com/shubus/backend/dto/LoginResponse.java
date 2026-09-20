package com.shubus.backend.dto;

public record LoginResponse(
        String regNo,
        String name,
        Boolean active,
        String message
) {
}