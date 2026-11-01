package com.shubus.backend.util;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public final class ShuttleSlotRules {

    private static final List<String> ALANDUR_SLOTS =
            List.of("A1", "A2", "A3", "A4", "A5");
    private static final List<String> VELACHERY_SLOTS =
            List.of("V1", "V2", "V3");
    private static final Set<String> SINGLE_SHUTTLE_SLOTS =
            Set.of("S1", "T1");
    private static final Set<String> LEGACY_GROUPS =
            Set.of("ALANDUR_METRO", "VELACHERY");
    private static final Set<String> SUPPORTED_SLOTS = Set.of(
            "A1", "A2", "A3", "A4", "A5",
            "V1", "V2", "V3", "S1", "T1");

    private ShuttleSlotRules() {
    }

    public static boolean isSupported(String shuttleGroup) {
        if (shuttleGroup == null) {
            return false;
        }

        String group = normalize(shuttleGroup);
        return SUPPORTED_SLOTS.contains(group) || LEGACY_GROUPS.contains(group);
    }

    public static boolean isOpen(
            String shuttleGroup,
            Map<String, Long> bookedSeatsBySlot) {
        if (shuttleGroup == null) {
            return false;
        }

        String group = normalize(shuttleGroup);
        long capacity = SeatLayout.getStudentBookableSeatCount();
        if (bookedSeatsBySlot.getOrDefault(group, 0L) >= capacity) {
            return false;
        }

        if (LEGACY_GROUPS.contains(group) || SINGLE_SHUTTLE_SLOTS.contains(group)) {
            return true;
        }

        List<String> sequence;
        if (ALANDUR_SLOTS.contains(group)) {
            sequence = ALANDUR_SLOTS;
        } else if (VELACHERY_SLOTS.contains(group)) {
            sequence = VELACHERY_SLOTS;
        } else {
            return false;
        }
        int slotIndex = sequence.indexOf(group);
        for (int index = 0; index < slotIndex; index++) {
            if (bookedSeatsBySlot.getOrDefault(sequence.get(index), 0L) < capacity) {
                return false;
            }
        }

        return true;
    }

    public static String normalize(String shuttleGroup) {
        return shuttleGroup.trim().toUpperCase(Locale.ROOT);
    }
}
