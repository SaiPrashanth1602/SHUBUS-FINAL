package com.shubus.backend.util;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class SeatLayoutTest {

    @Test
    void studentCapacityExcludesTheFacultyOnlyRow() {
        assertEquals(55, SeatLayout.getAllSeats().size());
        assertEquals(50, SeatLayout.getStudentBookableSeatCount());
        assertTrue(SeatLayout.isFacultySeat("5A"));
        assertFalse(SeatLayout.isStudentBookableSeat("5A"));
        assertTrue(SeatLayout.isStudentBookableSeat("1A"));
        assertFalse(SeatLayout.isGirlsSeat("5A"));
        assertFalse(SeatLayout.isBoysSeat("5A"));
    }
}
