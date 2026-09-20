package com.shubus.backend.dto;

public record StudentResponse(
        String regNo,
        String name,
        Boolean active
) {
}