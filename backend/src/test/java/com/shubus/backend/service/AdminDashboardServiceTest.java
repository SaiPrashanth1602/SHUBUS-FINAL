package com.shubus.backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.Collections;

import com.shubus.backend.dto.AdminDashboardResponse;
import com.shubus.backend.repository.AdminDashboardRepository;
import org.junit.jupiter.api.Test;

class AdminDashboardServiceTest {

    @Test
    void dashboardCapacityUsesStudentBookableSeats() {
        AdminDashboardRepository repository =
                mock(AdminDashboardRepository.class);
        LocalDate date = LocalDate.of(2026, 11, 1);
        when(repository.getOverview(date)).thenReturn(
                Collections.singletonList(new Object[] {
                        "REGULAR", null, 2L, 4L
                }));

        AdminDashboardResponse dashboard =
                new AdminDashboardService(repository).getOverview(date);

        assertEquals(100, dashboard.regularCapacity());
        assertEquals(100, dashboard.totalCapacity());
    }
}
