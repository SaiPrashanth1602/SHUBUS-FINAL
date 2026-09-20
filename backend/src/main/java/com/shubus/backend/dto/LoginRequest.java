package com.shubus.backend.dto;

public record LoginRequest(
        String regNo,
        String password
) {
}