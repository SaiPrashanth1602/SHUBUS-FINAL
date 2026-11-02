package com.shubus.backend.util;

import java.util.Set;

public final class SeatLayout {

    private SeatLayout() {
    }

    /** Girls: rows 1-5. Faculty: row 6 (centre). Boys: rows 7-11. */
    private static final int GIRLS_FIRST_ROW = 1;
    private static final int GIRLS_LAST_ROW = 5;
    private static final int FACULTY_ROW = 6;
    private static final int BOYS_FIRST_ROW = 7;
    private static final int BOYS_LAST_ROW = 11;

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
            "10A", "10B", "10D", "10E", "10F",

            "11A", "11B", "11C", "11D", "11E", "11F"
    );

    public static boolean isValidSeat(String seat) {
        return seat != null && VALID_SEATS.contains(seat);
    }

    public static boolean isFacultySeat(String seat) {
        return isValidSeat(seat) && getRow(seat) == FACULTY_ROW;
    }

    public static boolean isStudentBookableSeat(String seat) {
        return isValidSeat(seat) && !isFacultySeat(seat);
    }

    public static boolean isGirlsSeat(String seat) {
        if (!isValidSeat(seat) || isFacultySeat(seat)) {
            return false;
        }

        int row = getRow(seat);
        return row >= GIRLS_FIRST_ROW && row <= GIRLS_LAST_ROW;
    }

    public static boolean isBoysSeat(String seat) {
        if (!isValidSeat(seat) || isFacultySeat(seat)) {
            return false;
        }

        int row = getRow(seat);
        return row >= BOYS_FIRST_ROW && row <= BOYS_LAST_ROW;
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

    public static int getStudentBookableSeatCount() {
        return (int) VALID_SEATS.stream()
                .filter(SeatLayout::isStudentBookableSeat)
                .count();
    }

    public static int getGirlsSeatCount() {
        return (int) VALID_SEATS.stream()
                .filter(SeatLayout::isGirlsSeat)
                .count();
    }

    public static int getBoysSeatCount() {
        return (int) VALID_SEATS.stream()
                .filter(SeatLayout::isBoysSeat)
                .count();
    }
}