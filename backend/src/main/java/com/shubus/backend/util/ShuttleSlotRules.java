package com.shubus.backend.util;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class ShuttleSlotRules {

    private static final Pattern SLOT_PATTERN =
            Pattern.compile("^([AVST])([1-9][0-9]*)$");

    private static final Set<String> LEGACY_GROUPS =
            Set.of("ALANDUR_METRO", "VELACHERY");

    private static final int DEFAULT_ALANDUR_SLOTS = 5;
    private static final int DEFAULT_VELACHERY_SLOTS = 3;
    private static final int DEFAULT_SHOLINGANALLUR_SLOTS = 1;
    private static final int DEFAULT_TAMBARAM_SLOTS = 1;

    public static final String AC = "AC";
    public static final String NON_AC = "NON_AC";

    private ShuttleSlotRules() {
    }

    public static boolean isSupported(String shuttleGroup) {
        if (shuttleGroup == null) {
            return false;
        }

        String group = normalize(shuttleGroup);
        return SLOT_PATTERN.matcher(group).matches()
                || LEGACY_GROUPS.contains(group);
    }

    public static String slotPrefix(String shuttleGroup) {
        if (shuttleGroup == null) {
            return null;
        }

        String group = normalize(shuttleGroup);
        Matcher matcher = SLOT_PATTERN.matcher(group);

        if (!matcher.matches()) {
            return null;
        }

        return matcher.group(1);
    }

    public static int slotNumber(String shuttleGroup) {
        if (shuttleGroup == null) {
            return -1;
        }

        String group = normalize(shuttleGroup);
        Matcher matcher = SLOT_PATTERN.matcher(group);

        if (!matcher.matches()) {
            return -1;
        }

        return Integer.parseInt(matcher.group(2));
    }

    /**
     * Slot rule: A, V, S -> AC only. T -> Non-AC only.
     * Returns null for legacy / unknown groups.
     */
    public static String allowedAcType(String shuttleGroup) {
        String prefix = slotPrefix(shuttleGroup);

        if (prefix == null) {
            return null;
        }

        return switch (prefix) {
            case "A", "V", "S" -> "AC";
            case "T" -> "NON-AC";
            default -> null;
        };
    }

    /**
     * Normalizes AC values to "AC" or "NON_AC".
     * Accepts: AC, NON_AC, NON-AC, "non ac", nonac (any case).
     * Returns null when the value is blank or unrecognised.
     */
    public static String normalizeAcType(String acType) {
        if (acType == null) {
            return null;
        }

        String cleaned = acType.trim()
                .toUpperCase(Locale.ROOT)
                .replaceAll("[^A-Z]", "");

        if (cleaned.isEmpty()) {
            return null;
        }

        if (cleaned.startsWith("NON")) {
            return NON_AC;
        }

        if (cleaned.equals("AC")) {
            return AC;
        }

        return null;
    }

    public static boolean sameAcType(String first, String second) {
        String a = normalizeAcType(first);
        String b = normalizeAcType(second);
        return a != null && a.equals(b);
    }

    /**
     * True when a student with [studentAcType] may see / book this shuttle.
     * The slot prefix decides (A/V/S = AC, T = Non-AC). Legacy groups fall
     * back to the bus's own AC type.
     */
    public static boolean isShuttleAllowedForAcType(
            String shuttleGroup,
            String routeAcType,
            String studentAcType) {

        String required = normalizeAcType(allowedAcType(shuttleGroup));

        if (required == null) {
            required = normalizeAcType(routeAcType);
        }

        String student = normalizeAcType(studentAcType);

        return required != null && required.equals(student);
    }

    public static List<String> requiredPreviousSlots(String shuttleGroup) {
        String prefix = slotPrefix(shuttleGroup);
        int number = slotNumber(shuttleGroup);

        if (prefix == null || number <= 1) {
            return List.of();
        }

        List<String> previous = new ArrayList<>();

        for (int i = 1; i < number; i++) {
            previous.add(prefix + i);
        }

        return previous;
    }

    public static boolean isDefaultSlot(String shuttleGroup) {
        String prefix = slotPrefix(shuttleGroup);
        int number = slotNumber(shuttleGroup);

        if (prefix == null) {
            return false;
        }

        return switch (prefix) {
            case "A" -> number >= 1 && number <= DEFAULT_ALANDUR_SLOTS;
            case "V" -> number >= 1 && number <= DEFAULT_VELACHERY_SLOTS;
            case "S" -> number >= 1 && number <= DEFAULT_SHOLINGANALLUR_SLOTS;
            case "T" -> number >= 1 && number <= DEFAULT_TAMBARAM_SLOTS;
            default -> false;
        };
    }

    public static boolean isOpen(
            String shuttleGroup,
            Map<String, Long> bookedSeatsBySlot) {

        if (shuttleGroup == null) {
            return false;
        }

        String group = normalize(shuttleGroup);

        if (!isSupported(group)) {
            return false;
        }

        long capacity = SeatLayout.getStudentBookableSeatCount();

        if (bookedSeatsBySlot.getOrDefault(group, 0L) >= capacity) {
            return false;
        }

        if (LEGACY_GROUPS.contains(group)) {
            return true;
        }

        for (String previousSlot : requiredPreviousSlots(group)) {
            long previousBookings =
                    bookedSeatsBySlot.getOrDefault(previousSlot, 0L);

            if (previousBookings < capacity) {
                return false;
            }
        }

        return true;
    }

    public static String normalize(String shuttleGroup) {
        return shuttleGroup.trim().toUpperCase(Locale.ROOT);
    }
}
