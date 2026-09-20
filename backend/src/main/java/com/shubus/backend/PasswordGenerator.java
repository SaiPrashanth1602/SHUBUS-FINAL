package com.shubus.backend;

import java.util.Scanner;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

public class PasswordGenerator {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        System.out.print("Enter admin password: ");
        String password = scanner.nextLine();

        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

        System.out.println("\nBCrypt Hash:");
        System.out.println(encoder.encode(password));

        scanner.close();
    }
}