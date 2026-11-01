package com.shubus.backend.util;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

class ShuttleSlotRulesTest {

    @Test
    void opensNextAlandurShuttleAtFiftyBookings() {
        assertFalse(ShuttleSlotRules.isOpen("A1", Map.of("A1", 50L)));
        assertFalse(ShuttleSlotRules.isOpen("A2", Map.of("A1", 49L)));
        assertTrue(ShuttleSlotRules.isOpen("A2", Map.of("A1", 50L)));
    }

    @Test
    void laterShuttlesRequireEveryEarlierSlotToBeFull() {
        assertFalse(ShuttleSlotRules.isOpen(
                "A3", Map.of("A1", 50L, "A2", 49L)));
        assertTrue(ShuttleSlotRules.isOpen(
                "A3", Map.of("A1", 50L, "A2", 50L)));
    }

    @Test
    void shuttleSequencesAreIndependentAndFirstSlotsAreInitiallyOpen() {
        assertTrue(ShuttleSlotRules.isOpen("A1", Map.of()));
        assertTrue(ShuttleSlotRules.isOpen("V1", Map.of()));
        assertFalse(ShuttleSlotRules.isOpen("V2", Map.of("A1", 50L)));
        assertTrue(ShuttleSlotRules.isOpen("V2", Map.of("V1", 50L)));
    }
}
