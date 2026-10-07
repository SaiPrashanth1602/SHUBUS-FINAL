package com.shubus.backend.util;

import java.util.Set;

public final class SeatLayout {

    private SeatLayout() {
    }

    private static final Set<String> VALID_SEATS = Set.of(
            "1A", "1D", "1E", "1F",

            "2A", "2B", "2D", "2E", "2F",
            "3A", "3B", "3D", "3E", "3F",
            "4A", "4B", "4D", "4E", "4F",
            "5A", "5B", "5D", "5E", "5F",
            "6A", "6B", "6D", "6E", "6F",
            "7A", "7B", "7D", "7E", "7F",
            "8A", "8B", "8D", "8E", "8F",
            "9A", "9B", "9D", "9E", "9F",

            "10A", "10B", "10C", "10D", "10E", "10F"
    );

    public static boolean isValidSeat(String seat) {
        return seat != null && VALID_SEATS.contains(seat);
    }

    public static boolean isFacultySeat(String seat) {
        return seat != null && seat.startsWith("5");
    }

    public static boolean isGirlsSeat(String seat) {
        if (!isValidSeat(seat) || isFacultySeat(seat)) {
            return false;
        }

        int row = getRow(seat);
        return row >= 1 && row <= 4;
    }

    public static boolean isBoysSeat(String seat) {
        if (!isValidSeat(seat) || isFacultySeat(seat)) {
            return false;
        }

        int row = getRow(seat);
        return row >= 6 && row <= 10;
    }

    private static int getRow(String seat) {
        int index = 0;

        while (index < seat.length()
                && Character.isDigit(seat.charAt(index))) {
            index++;
        }

        return Integer.parseInt(seat.substring(0, index));
    }

    public static Set<String> getAllSeats() {
    return VALID_SEATS;
}
}   