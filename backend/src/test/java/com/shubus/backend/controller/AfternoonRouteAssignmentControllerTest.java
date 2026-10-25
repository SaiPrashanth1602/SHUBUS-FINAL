package com.shubus.backend.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;

import com.shubus.backend.model.AfternoonRouteAssignment;
import com.shubus.backend.model.Route;
import com.shubus.backend.repository.AfternoonRouteAssignmentRepository;
import com.shubus.backend.repository.RouteRepository;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

class AfternoonRouteAssignmentControllerTest {

    @Test
    void rangeReturnsAssignmentsAtBothInclusiveBoundaries() {
        AfternoonRouteAssignmentRepository assignmentRepository =
                mock(AfternoonRouteAssignmentRepository.class);
        RouteRepository routeRepository = mock(RouteRepository.class);
        LocalDate start = LocalDate.of(2026, 11, 1);
        LocalDate end = LocalDate.of(2027, 11, 1);
        AfternoonRouteAssignment first = assignment(start, 1L);
        AfternoonRouteAssignment last = assignment(end, 2L);
        when(assignmentRepository.findByAssignmentDateBetween(start, end))
                .thenReturn(List.of(first, last));

        var results = new AfternoonRouteAssignmentController(
                assignmentRepository, routeRepository)
                .getAssignments(start, end);

        assertEquals(2, results.size());
        assertEquals(start, results.get(0).assignmentDate());
        assertEquals(end, results.get(1).assignmentDate());
        verify(assignmentRepository).findByAssignmentDateBetween(start, end);
        verify(assignmentRepository, never()).findByAssignmentDate(start);
    }

    @Test
    void reversedRangeIsRejectedWithoutQueryingTheRepository() {
        AfternoonRouteAssignmentRepository assignmentRepository =
                mock(AfternoonRouteAssignmentRepository.class);

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> new AfternoonRouteAssignmentController(
                        assignmentRepository, mock(RouteRepository.class))
                        .getAssignments(
                                LocalDate.of(2026, 11, 2),
                                LocalDate.of(2026, 11, 1)));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        verify(assignmentRepository, never())
                .findByAssignmentDateBetween(
                        org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.any());
    }

    private AfternoonRouteAssignment assignment(LocalDate date, long id) {
        Route route = mock(Route.class);
        when(route.getId()).thenReturn(id + 10);
        when(route.getRouteNumber()).thenReturn("BUS-" + id);
        when(route.getRouteName()).thenReturn("Route " + id);
        when(route.getAcType()).thenReturn("AC");

        AfternoonRouteAssignment assignment =
                mock(AfternoonRouteAssignment.class);
        when(assignment.getId()).thenReturn(id);
        when(assignment.getRoute()).thenReturn(route);
        when(assignment.getAssignmentDate()).thenReturn(date);
        when(assignment.getAssignmentType()).thenReturn("REGULAR");
        return assignment;
    }
}
