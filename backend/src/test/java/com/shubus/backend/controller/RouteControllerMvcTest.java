package com.shubus.backend.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.shubus.backend.model.Route;
import com.shubus.backend.repository.RouteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class RouteControllerMvcTest {

    private RouteRepository repository;
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        repository = mock(RouteRepository.class);
        mvc = MockMvcBuilders
                .standaloneSetup(new RouteController(repository))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void postRouteReturnsRouteCodeAndRouteCodeAllowedValues() throws Exception {
        Route saved = mock(Route.class);
        when(repository.existsByRouteNumberIgnoreCase("BUS-12"))
                .thenReturn(false);
        when(repository.existsByRouteCodeIgnoreCase("RTE-NORTH"))
                .thenReturn(false);
        when(repository.save(any(Route.class))).thenReturn(saved);
        when(saved.getId()).thenReturn(12L);
        when(saved.getRouteNumber()).thenReturn("BUS-12");
        when(saved.getRouteCode()).thenReturn("RTE-NORTH");
        when(saved.getRouteName()).thenReturn("North");
        when(saved.getAcType()).thenReturn("AC");
        when(saved.getAllowedRoutes()).thenReturn(new String[] {"RTE-SOUTH"});

        mvc.perform(post("/api/admin/routes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "routeNumber": "BUS-12",
                                  "routeCode": "RTE-NORTH",
                                  "routeName": "North",
                                  "acType": "AC",
                                  "allowedRoutes": ["RTE-SOUTH"]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(12))
                .andExpect(jsonPath("$.routeNumber").value("BUS-12"))
                .andExpect(jsonPath("$.routeCode").value("RTE-NORTH"))
                .andExpect(jsonPath("$.allowedRoutes[0]").value("RTE-SOUTH"));
    }

    @Test
    void getRouteUsesThePathDatabaseIdAndReturnsRouteCode() throws Exception {
        Route route = mock(Route.class);
        when(repository.findById(12L)).thenReturn(java.util.Optional.of(route));
        when(route.getId()).thenReturn(12L);
        when(route.getRouteNumber()).thenReturn("BUS-112");
        when(route.getRouteCode()).thenReturn("RTE-NORTH");
        when(route.getRouteName()).thenReturn("North");
        when(route.getAcType()).thenReturn("AC");
        when(route.getAllowedRoutes()).thenReturn(new String[] {"RTE-SOUTH"});

        mvc.perform(get("/api/admin/routes/12"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(12))
                .andExpect(jsonPath("$.routeNumber").value("BUS-112"))
                .andExpect(jsonPath("$.routeCode").value("RTE-NORTH"))
                .andExpect(jsonPath("$.allowedRoutes[0]").value("RTE-SOUTH"));
    }

    @Test
    void missingRouteReturnsNotFound() throws Exception {
        when(repository.findById(404L)).thenReturn(java.util.Optional.empty());

        mvc.perform(get("/api/admin/routes/404"))
                .andExpect(status().isNotFound());
    }
}
