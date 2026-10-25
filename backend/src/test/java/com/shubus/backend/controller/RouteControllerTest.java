package com.shubus.backend.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import com.shubus.backend.model.Route;
import com.shubus.backend.repository.RouteRepository;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

class RouteControllerTest {

    @Test
    void createReturnsDistinctRouteIdNumberCodeAndAllowedRouteCodes() {
        RouteRepository repository = mock(RouteRepository.class);
        Route saved = mock(Route.class);
        when(repository.existsByRouteNumberIgnoreCase("BUS-7"))
                .thenReturn(false);
        when(repository.existsByRouteCodeIgnoreCase("R7"))
                .thenReturn(false);
        when(repository.save(org.mockito.ArgumentMatchers.any(Route.class)))
                .thenReturn(saved);
        when(saved.getId()).thenReturn(7L);
        when(saved.getRouteNumber()).thenReturn("BUS-7");
        when(saved.getRouteCode()).thenReturn("R7");
        when(saved.getRouteName()).thenReturn("North");
        when(saved.getAcType()).thenReturn("AC");
        when(saved.getAllowedRoutes()).thenReturn(new String[] {"R6"});

        Route request = new Route();
        request.setRouteNumber(" BUS-7 ");
        request.setRouteCode(" R7 ");
        request.setRouteName("North");
        request.setAcType("AC");
        request.setAllowedRoutes(new String[] {"R6"});

        var response = new RouteController(repository).createRoute(request);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(7L, response.getBody().id());
        assertEquals("BUS-7", response.getBody().routeNumber());
        assertEquals("R7", response.getBody().routeCode());
        assertEquals("R6", response.getBody().allowedRoutes()[0]);
        assertEquals("BUS-7", request.getRouteNumber());
        assertEquals("R7", request.getRouteCode());
    }

    @Test
    void getRouteUsesDatabaseIdAndReturnsRouteCodeSeparately() {
        RouteRepository repository = mock(RouteRepository.class);
        Route route = mock(Route.class);
        when(repository.findById(7L)).thenReturn(Optional.of(route));
        when(route.getId()).thenReturn(7L);
        when(route.getRouteNumber()).thenReturn("BUS-107");
        when(route.getRouteCode()).thenReturn("NORTH");
        when(route.getRouteName()).thenReturn("North");
        when(route.getAcType()).thenReturn("AC");
        when(route.getAllowedRoutes()).thenReturn(new String[] {"SOUTH"});

        var response = new RouteController(repository).getRoute(7L);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(7L, response.getBody().id());
        assertEquals("BUS-107", response.getBody().routeNumber());
        assertEquals("NORTH", response.getBody().routeCode());
        assertEquals("SOUTH", response.getBody().allowedRoutes()[0]);
        verify(repository).findById(7L);
    }

    @Test
    void updateWithoutRouteCodePreservesTheExistingCodeAndOtherFields() {
        RouteRepository repository = mock(RouteRepository.class);
        Route existing = mock(Route.class);
        when(repository.findById(7L)).thenReturn(Optional.of(existing));
        when(repository.save(existing)).thenReturn(existing);
        when(existing.getId()).thenReturn(7L);
        when(existing.getRouteNumber()).thenReturn("BUS-7");
        when(existing.getRouteCode()).thenReturn("R7");
        when(existing.getRouteName()).thenReturn("North");
        when(existing.getAcType()).thenReturn("AC");
        String[] allowedRoutes = {"R6"};
        when(existing.getAllowedRoutes()).thenReturn(allowedRoutes);

        Route update = new Route();
        update.setRouteName("Updated North");

        var response = new RouteController(repository).updateRoute(7L, update);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("BUS-7", response.getBody().routeNumber());
        assertEquals("R7", response.getBody().routeCode());
        verify(existing).setRouteName("Updated North");
        verify(existing, never()).setRouteCode(org.mockito.ArgumentMatchers.anyString());
        verify(existing, never()).setRouteNumber(org.mockito.ArgumentMatchers.anyString());
        verify(existing, never()).setAllowedRoutes(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void updateAcceptsAValidNewRouteCodeWithoutConfusingIdentifiers() {
        RouteRepository repository = mock(RouteRepository.class);
        Route existing = mock(Route.class);
        when(repository.findById(7L)).thenReturn(Optional.of(existing));
        when(repository.existsByRouteCodeIgnoreCaseAndIdNot("SOUTH", 7L))
                .thenReturn(false);
        when(existing.getId()).thenReturn(7L);
        when(existing.getRouteNumber()).thenReturn("BUS-107");
        when(existing.getRouteCode()).thenReturn("SOUTH");
        when(existing.getRouteName()).thenReturn("South");
        when(existing.getAcType()).thenReturn("AC");
        when(existing.getAllowedRoutes()).thenReturn(new String[] {"NORTH"});
        when(repository.save(existing)).thenReturn(existing);

        Route update = new Route();
        update.setRouteCode(" SOUTH ");

        var response = new RouteController(repository).updateRoute(7L, update);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(7L, response.getBody().id());
        assertEquals("BUS-107", response.getBody().routeNumber());
        assertEquals("SOUTH", response.getBody().routeCode());
        verify(existing).setRouteCode("SOUTH");
        verify(repository).existsByRouteCodeIgnoreCaseAndIdNot("SOUTH", 7L);
    }

    @Test
    void invalidUpdateDoesNotMutateOrSaveAnySuppliedFields() {
        RouteRepository repository = mock(RouteRepository.class);
        Route existing = mock(Route.class);
        when(repository.findById(7L)).thenReturn(Optional.of(existing));
        when(repository.existsByRouteNumberIgnoreCaseAndIdNot("BUS-8", 7L))
                .thenReturn(false);

        Route update = new Route();
        update.setRouteNumber("BUS-8");
        update.setRouteCode(" ");
        update.setRouteName("Changed North");

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> new RouteController(repository).updateRoute(7L, update));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        verify(existing, never()).setRouteNumber(org.mockito.ArgumentMatchers.anyString());
        verify(existing, never()).setRouteCode(org.mockito.ArgumentMatchers.anyString());
        verify(existing, never()).setRouteName(org.mockito.ArgumentMatchers.anyString());
        verify(repository, never()).save(existing);
    }

    @Test
    void createRequiresANonblankRouteCode() {
        RouteRepository repository = mock(RouteRepository.class);
        Route route = new Route();
        route.setRouteNumber("BUS-7");
        route.setRouteName("North");
        route.setAcType("AC");
        route.setAllowedRoutes(new String[0]);

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> new RouteController(repository).createRoute(route));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        verify(repository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void createRejectsDuplicateRouteCodesCaseInsensitively() {
        RouteRepository repository = mock(RouteRepository.class);
        when(repository.existsByRouteNumberIgnoreCase("BUS-7"))
                .thenReturn(false);
        when(repository.existsByRouteCodeIgnoreCase("r7"))
                .thenReturn(true);

        Route route = new Route();
        route.setRouteNumber("BUS-7");
        route.setRouteCode("r7");
        route.setRouteName("North");
        route.setAcType("AC");
        route.setAllowedRoutes(new String[0]);

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> new RouteController(repository).createRoute(route));

        assertEquals(HttpStatus.CONFLICT, error.getStatusCode());
        verify(repository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void updateRejectsDuplicateRouteCodesWithoutSaving() {
        RouteRepository repository = mock(RouteRepository.class);
        Route existing = mock(Route.class);
        when(repository.findById(7L)).thenReturn(Optional.of(existing));
        when(repository.existsByRouteCodeIgnoreCaseAndIdNot("R8", 7L))
                .thenReturn(true);

        Route update = new Route();
        update.setRouteCode("R8");

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> new RouteController(repository).updateRoute(7L, update));

        assertEquals(HttpStatus.CONFLICT, error.getStatusCode());
        verify(existing, never()).setRouteCode(org.mockito.ArgumentMatchers.anyString());
        verify(repository, never()).save(existing);
    }
}
