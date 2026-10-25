package com.shubus.backend.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import java.util.Map;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.server.ResponseStatusException;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler =
            new GlobalExceptionHandler();

    @Test
    void validationErrorsRemainActionableBadRequests() {
        var response = handler.handleInvalidArgument(
                new IllegalArgumentException("Route code is required"));

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertEquals(
                "Route code is required",
                response.getBody().get("error"));
    }

    @Test
    void notFoundAndConflictStatusesArePreserved() {
        var notFound = handler.handleResponseStatusException(
                new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Route not found"));
        var conflict = handler.handleResponseStatusException(
                new ResponseStatusException(
                        HttpStatus.CONFLICT, "Route code already exists"));

        assertEquals(HttpStatus.NOT_FOUND, notFound.getStatusCode());
        assertEquals(HttpStatus.CONFLICT, conflict.getStatusCode());
    }

    @Test
    void malformedRequestsConflictsAndUnsupportedRequestsUseClientStatuses() {
        var invalid = handler.handleUnreadableRequest(
                new MissingServletRequestParameterException(
                        "date", "LocalDate"));
        var conflict = handler.handleDataConflict(
                new DataIntegrityViolationException("private constraint detail"));
        var method = handler.handleMethodNotAllowed(
                new HttpRequestMethodNotSupportedException("TRACE"));
        var media = handler.handleUnsupportedMediaType(
                new HttpMediaTypeNotSupportedException("unsupported content type"));

        assertEquals(HttpStatus.BAD_REQUEST, invalid.getStatusCode());
        assertEquals("Invalid request data", invalid.getBody().get("error"));
        assertEquals(HttpStatus.CONFLICT, conflict.getStatusCode());
        assertFalse(
                conflict.getBody().toString().contains("private constraint detail"));
        assertEquals(HttpStatus.METHOD_NOT_ALLOWED, method.getStatusCode());
        assertEquals(
                HttpStatus.UNSUPPORTED_MEDIA_TYPE,
                media.getStatusCode());
    }

    @Test
    void unexpectedFailuresReturnGenericServerErrors() {
        var response = handler.handleUnexpectedException(
                new IllegalStateException("private database detail"));

        assertEquals(
                HttpStatus.INTERNAL_SERVER_ERROR,
                response.getStatusCode());
        assertFalse(response.getBody().toString().contains("private database detail"));
    }

    @Test
    void loginValidationKeepsItsExistingSafeClientErrorResponse() {
        HttpServletRequest request = new MockHttpServletRequest(
                "POST", "/api/admin/auth/login");
        var response = handler.handleRuntimeException(
                new RuntimeException("Employee ID not found"),
                request);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertEquals(
                Map.of("error", "Employee ID not found"),
                response.getBody());
    }

    @Test
    void unexpectedLoginErrorsDoNotExposeInternalMessages() {
        HttpServletRequest request = new MockHttpServletRequest(
                "POST", "/api/admin/auth/login");
        var response = handler.handleRuntimeException(
                new RuntimeException("sql password detail"),
                request);

        assertEquals(
                HttpStatus.INTERNAL_SERVER_ERROR,
                response.getStatusCode());
        assertFalse(response.getBody().toString().contains("sql password detail"));
    }
}
