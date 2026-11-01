# SHUBUS — Software Development & System Documentation

> **Purpose:** Developer handover for the SHUBUS Admin and SHUBUS Student applications and the Spring Boot API they share. This document describes the checked-in source structure and current application behavior; it is not a production deployment or security certification.

## Table of Contents

1. [System at a Glance](#1-system-at-a-glance)
2. [Projects and Responsibilities](#2-projects-and-responsibilities)
3. [Technology Stack](#3-technology-stack)
4. [System Architecture and Data Flow](#4-system-architecture-and-data-flow)
5. [SHUBUS Admin Application](#5-shubus-admin-application)
6. [Backend API](#6-backend-api)
7. [SHUBUS Student Application](#7-shubus-student-application)
8. [Shared API Contract](#8-shared-api-contract)
9. [Operational Rules and Data](#9-operational-rules-and-data)
10. [Configuration and Local Development](#10-configuration-and-local-development)
11. [Testing and Validation](#11-testing-and-validation)
12. [Troubleshooting](#12-troubleshooting)
13. [Safe Modification Guide](#13-safe-modification-guide)
14. [Developer Handover](#14-developer-handover)

---

# 1. System at a Glance

SHUBUS is a campus transport system consisting of two Flutter applications and a shared REST API:

| Component | Repository | Primary user | Responsibility |
|---|---|---|---|
| Admin app | [SHUBUS-ADMIN](https://github.com/SaiPrashanth1602/SHUBUS-ADMIN) | Transport administrator | Maintain routes and assignments; review dashboard and booking capacity |
| Student app | [SHUBUS-STUDENT](https://github.com/SaiPrashanth1602/SHUBUS-STUDENT) | Student | View transport profile and routes; select a shuttle seat; manage bookings |
| Backend | `backend/` in SHUBUS-ADMIN | Both apps | Expose REST endpoints and read/write transport data in PostgreSQL |

```text
┌─────────────────────┐        HTTPS/HTTP REST        ┌──────────────────────┐
│ SHUBUS Admin Flutter│ ────────────────────────────► │                      │
└─────────────────────┘                               │ Spring Boot API      │
                                                      │ (default port 8081) │
┌─────────────────────┐        HTTPS/HTTP REST        │                      │
│ SHUBUS Student      │ ────────────────────────────► │                      │
│ Flutter             │                               └──────────┬───────────┘
└─────────────────────┘                                          │ JPA
                                                                 ▼
                                                      ┌──────────────────────┐
                                                      │ PostgreSQL database  │
                                                      └──────────────────────┘
```

The Admin repository contains both the Admin frontend and the API. The Student repository contains its own Flutter frontend and calls that API. The apps do not communicate directly with each other.

# 2. Projects and Responsibilities

## 2.1 SHUBUS Admin repository

The repository is arranged as two separate build roots:

```text
SHUBUS-ADMIN/
├── backend/   Spring Boot API and PostgreSQL/JPA integration
├── frontend/  Admin Flutter application
├── README.md  Admin project quick start
└── SDC.md     Shared system and developer handover
```

## 2.2 SHUBUS Student repository

```text
SHUBUS-STUDENT/
├── frontend/     Student app source and Flutter package (run the app here)
├── pubspec.yaml  Additional root-level manifest; not the app source directory
└── README.md     Student project quick start
```

The Admin app and Student app have independent Flutter packages and are installed and launched from their respective `frontend/` directories. The Student repository also has a root-level `pubspec.yaml`; the documented Student application source is under `frontend/lib/`, so use the `frontend/` package for development and launch commands.

# 3. Technology Stack

| Area | Technology |
|---|---|
| Admin and Student apps | Flutter, Dart, Material |
| Flutter networking | `http` |
| Backend | Java 21, Spring Boot 4.1.1, Spring MVC, Spring Data JPA |
| Database | PostgreSQL |
| Backend build | Maven Wrapper (`mvnw.cmd`) |
| API data format | JSON over HTTP |

The projects use separate Flutter packages. A change to a shared API response may require coordinated changes to the backend DTO, Admin service/model, and Student repository/model.

# 4. System Architecture and Data Flow

## 4.1 Administrative setup and student booking

```text
Admin user
   │ maintains routes, allowed route codes and afternoon assignments
   ▼
Admin Flutter ──► Spring Boot API ──► PostgreSQL
                                       │
                                       ├── routes and allowed-route mappings
                                       ├── afternoon route assignments
                                       ├── student / transport profile data
                                       └── bookings
                                       ▲
Student Flutter ───────────────────────┘
   │ views routes and assignments, reads seats, creates/cancels bookings
   └─────────────────────────────────────────────────────────────────────
```

The Student app requests available assignments for the signed-in registration number and target date. The backend returns assignments suitable for that student. The app then requests seat availability for the selected assignment and date. The backend validates booking rules and persists booking changes.

## 4.2 Request flow

1. A Flutter screen calls a repository or service.
2. The client sends a JSON or query-parameter request to the configured API base URL.
3. A Spring MVC controller maps the endpoint to a service/repository operation.
4. Spring Data JPA reads or writes PostgreSQL records.
5. The backend returns a response DTO or an HTTP error.
6. The Flutter client converts successful JSON into app models and presents loading, empty, or error states.

# 5. SHUBUS Admin Application

## 5.1 Main capabilities

- Employee-ID sign-in.
- Dashboard summary and schedule/seat-capacity information.
- Route listing and create, edit, and delete workflows.
- Route number, route code, route name, AC type, and Allowed Routes editing.
- Afternoon assignment discovery, creation, update, removal, and manual refresh.
- Schedule lookups by date or date range.

## 5.2 Frontend structure

```text
frontend/lib/
├── main.dart
├── models/
│   └── route_model.dart
├── screens/
│   ├── admin_login_screen.dart
│   ├── admin_dashboard_screen.dart
│   ├── routes_screen.dart
│   └── afternoon_assignment_screen.dart
├── services/
│   ├── api_config.dart
│   └── route_service.dart
└── widgets/
    └── route_form.dart
```

### Important files

| File | Responsibility |
|---|---|
| `frontend/lib/main.dart` | Creates the Admin `MaterialApp` and starts at the login screen |
| `frontend/lib/services/api_config.dart` | Provides the API base URL, optionally overridden with `API_BASE_URL` |
| `frontend/lib/services/route_service.dart` | HTTP operations for routes, assignments, schedules, and dashboard data |
| `frontend/lib/models/route_model.dart` | Route response parsing and Admin route model |
| `frontend/lib/screens/admin_login_screen.dart` | Employee-ID login request |
| `frontend/lib/screens/admin_dashboard_screen.dart` | Admin overview and date-based schedule |
| `frontend/lib/screens/routes_screen.dart` | Route list, refresh, and route management |
| `frontend/lib/widgets/route_form.dart` | Reusable route create/edit form |
| `frontend/lib/screens/afternoon_assignment_screen.dart` | Assignment discovery and management |

## 5.3 Admin service behavior

- Requests use the configured base URL and a 20-second timeout.
- Route and assignment screens expose user-triggered refresh actions; the dashboard uses date-range assignment data and loads detailed schedule information as needed.
- Route codes are shown and searched as route codes, not inferred from bus numbers.
- Allowed Routes are represented by route-code strings in the existing API contract.
- Route creation requires non-blank route number, code, name, and AC type. The backend rejects duplicate route numbers or codes without regard to case.
- Existing assignment actions use the backend assignment endpoints; the dashboard schedule endpoint includes seat totals that are not present in the assignment-management response.

# 6. Backend API

## 6.1 Backend layers

```text
backend/src/main/java/com/shubus/backend/
├── BackendApplication.java
├── config/       Password encoder configuration
├── controller/   HTTP routes and request/response mapping
├── dto/          API request and response types
├── model/        JPA entities
├── repository/   Spring Data persistence interfaces
├── service/      Booking, assignment, authentication, and dashboard rules
└── util/         Booking-window, shuttle-slot, and seat-layout rules
```

Important backend files include:

| Area | Examples |
|---|---|
| Controllers | `RouteController`, `AfternoonRouteAssignmentController`, `StudentBookingController`, `StudentSeatController` |
| Services | `BookingService`, `SeatService`, `AfternoonScheduleService`, `StudentAfternoonRouteService` |
| Entities | `Route`, `AfternoonRouteAssignment`, `Booking`, `Student`, `Bus` |
| Rules | `BookingTimeRules`, `SeatLayout`, `ShuttleSlotRules` |
| Configuration | `application.properties`, `application.properties.example` |

## 6.2 Persistence

The backend uses Spring Data JPA with PostgreSQL. The configured Hibernate schema mode is `none`; the application does not create or update the database schema automatically. Schema changes and production data maintenance must follow the database owner's migration process. No schema migration should be inferred from entity changes alone.

**Credential handling:** the checked-in `backend/src/main/resources/application.properties` currently contains concrete datasource credentials. Treat those credentials as exposed: rotate them with the database provider, remove them from tracked source, and use environment-specific secret storage. Do not copy credential values into documentation, screenshots, or issue reports. `application.properties.example` should contain placeholders only.

## 6.3 Health check

The backend exposes `GET /api/health`. Use it to distinguish API reachability from database- or feature-specific failures; a successful health response does not validate every database workflow.

# 7. SHUBUS Student Application

## 7.1 Main capabilities

- Sign in with a student registration number.
- View the student's transport profile and morning route.
- Browse routes and filter by search text or AC type.
- View afternoon assignments available to the student.
- Inspect seat availability and submit a booking.
- Review a booking and cancel an eligible booking.
- Refresh dashboard data and retry recoverable failed requests.

## 7.2 Frontend structure

```text
frontend/lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── theme/app_theme.dart
├── core/
│   ├── config/api_config.dart
│   ├── errors/app_exception.dart
│   ├── network/api_client.dart
│   ├── utils/booking_window.dart
│   └── widgets/status_views.dart
└── features/
    ├── auth/
    ├── bookings/
    ├── dashboard/
    ├── profile/
    ├── routes/
    ├── seat_selection/
    └── student_repository.dart
```

### Important files

| File | Responsibility |
|---|---|
| `frontend/lib/main.dart` | Starts `ShubusStudentApp` |
| `frontend/lib/app/app.dart` | Owns the login/session state and creates the repository |
| `frontend/lib/core/config/api_config.dart` | Requires `API_BASE_URL`, builds API URIs, and sets the request timeout |
| `frontend/lib/core/network/api_client.dart` | Sends requests, decodes JSON, and maps network/HTTP failures |
| `frontend/lib/features/student_repository.dart` | Student-facing API operations and model conversion |
| `frontend/lib/features/dashboard/student_dashboard_screen.dart` | Profile, booking, and assignment overview |
| `frontend/lib/features/dashboard/student_shell.dart` | Navigation to profile, routes, seat booking, and bookings |
| `frontend/lib/features/seat_selection/seat_selection_screen.dart` | Assignment selection, seat status, and booking confirmation |
| `frontend/lib/features/seat_selection/seat_layout.dart` | Client-side seat grid rendering |
| `frontend/lib/features/bookings/bookings_screen.dart` | Booking lookup, date selection, and cancellation |
| `frontend/lib/core/utils/booking_window.dart` | Client-side target-date calculation in India Standard Time |

## 7.3 Student request and error handling

- The API base URL is required at build/run time; there is no silent default endpoint.
- `ApiClient` has a 12-second timeout and turns timeouts, socket failures, invalid JSON, and non-success HTTP responses into app-level exceptions.
- Registration numbers are URL-encoded when included in a path.
- Booking dates are sent as `yyyy-MM-dd`.
- A missing booking is treated as an empty booking state; other API errors are surfaced to the screen.
- The client-side date calculation is for presentation and selection. The backend must remain authoritative for booking eligibility.

# 8. Shared API Contract

The following paths are implemented by the backend. Some are used by the current Flutter apps; others are backend endpoints available to integrations. The exact JSON fields are defined by the DTOs in `backend/src/main/java/com/shubus/backend/dto/`.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/health` | Basic API health response |
| `POST` | `/api/admin/auth/login` | Admin employee-ID lookup/sign-in |
| `POST` | `/api/auth/login` | Student registration-number sign-in |
| `GET` | `/api/admin/routes` | List routes |
| `GET` | `/api/admin/routes/{id}` | Read a route |
| `POST` | `/api/admin/routes` | Create a route |
| `PUT` | `/api/admin/routes/{id}` | Update a route |
| `DELETE` | `/api/admin/routes/{id}` | Delete a route |
| `GET` | `/api/admin/afternoon-routes?date=...` | List assignments for a date |
| `GET` | `/api/admin/afternoon-routes?date=...&endDate=...` | List assignments over a date range |
| `POST` | `/api/admin/afternoon-routes/bulk` | Bulk-create assignments |
| `POST` | `/api/admin/afternoon-routes` | Create an assignment |
| `PUT` | `/api/admin/afternoon-routes/{id}` | Update assignment details |
| `DELETE` | `/api/admin/afternoon-routes/{id}` | Remove an assignment |
| `GET` | `/api/admin/schedule?date=...` | Admin schedule with booking/capacity data |
| `GET` | `/api/admin/dashboard` | Dashboard summary |
| `GET` | `/api/students/{regNo}` | Basic student details |
| `GET` | `/api/students/{regNo}/profile` | Student and transport-profile bootstrap response |
| `GET` | `/api/students/{regNo}/transport-profile` | Student profile and transport information |
| `GET` | `/api/students/{regNo}/afternoon-routes?date=...` | Assignments available to a student |
| `GET` | `/api/students/{regNo}/afternoon-routes/{assignmentId}/seats?date=...` | Seat status for an assignment |
| `POST` | `/api/students/bookings` | Create a booking |
| `GET` | `/api/students/{regNo}/bookings?date=...` | Retrieve a student's booking |
| `DELETE` | `/api/students/{regNo}/bookings/{bookingId}` | Cancel a booking |
| `GET` | `/api/buses` | List buses |
| `GET` | `/api/routes/{routeId}/buses` | List buses associated with a route |
| `GET` | `/api/registrations/{regNo}` | Read registration data |

Use the controller source as the authority for required parameters and request fields. Error response formats may vary by endpoint; clients should handle both HTTP status codes and documented response DTOs.

## 8.1 Authentication limitation

The current Student sign-in accepts a registration number only. The Admin sign-in accepts an employee ID only. The services check that the corresponding record exists and is active, but the Flutter clients do not establish or persist a token-based session. These flows identify an account; they are not strong authentication or an authorization boundary. Do not treat network reachability or the login screen as protection for sensitive operations. A production deployment needs an approved authentication and authorization design enforced by the backend.

# 9. Operational Rules and Data

## 9.1 Booking window

- Backend booking rules use the `Asia/Kolkata` time zone.
- The server permits booking from 14:00 on the day before travel until 13:45 on the booking date (the closing instant is exclusive).
- The Student app calculates a target booking date for the UI. The backend validates the actual request and may reject a date/assignment that is no longer bookable.

## 9.2 Seat layout and eligibility

- The physical seat layout contains 55 seats.
- Row 5 is reserved for faculty.
- The other 50 seats are student-bookable, subject to availability and the student's gender rules.
- The backend is authoritative for seat status, booking conflicts, student activity, assignment availability, and booking window. The frontend seat layout is a rendering aid, not a source of permission.

## 9.3 Routes and assignments

- Route number and route code are separate fields.
- Allowed Routes are persisted as route-code strings in the existing API contract.
- Afternoon assignments are date-specific and can be retrieved as a range for Admin discovery.
- Shuttle group/slot availability is governed by backend slot rules and booking capacity; do not assume all groups have the same sequencing behavior.

## 9.4 Database changes

No live database contents or migration state are represented in this document. Confirm the deployed schema and data with the database owner before changing entities, route mappings, assignment rules, or booking constraints.

# 10. Configuration and Local Development

## 10.1 Prerequisites

- Flutter SDK and a supported device/emulator.
- Java 21 for the backend.
- A PostgreSQL instance and approved credentials for the environment.
- Network access from each device to the backend host and port.

## 10.2 Start the backend (PowerShell)

Configure Spring datasource settings for the environment without committing credentials. Spring Boot environment variables can override the datasource configuration:

```powershell
# From the SHUBUS-ADMIN repository root
Set-Location backend
$env:SPRING_DATASOURCE_URL = 'jdbc:postgresql://<host>:5432/<database>?sslmode=require'
$env:SPRING_DATASOURCE_USERNAME = '<database-user>'
$env:SPRING_DATASOURCE_PASSWORD = '<database-password>'
.\mvnw.cmd spring-boot:run
```

Keep the backend listening on the configured port (8081 by default). Verify `GET http://localhost:8081/api/health` from the development machine. Do not expose a development database or service to an untrusted network.

## 10.3 Run the Admin app

```powershell
# From the SHUBUS-ADMIN repository root
Set-Location frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<backend-host>:8081
```

The Admin app has a development fallback URL in `frontend/lib/services/api_config.dart`; explicitly set `API_BASE_URL` for the target device. A physical phone must use a host/IP reachable on its network, not the phone's own `localhost`.

## 10.4 Run the Student app

```powershell
# From the SHUBUS-STUDENT repository root
Set-Location frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<backend-host>:8081
```

`API_BASE_URL` is mandatory in the Student app. Use a URL reachable from the selected emulator or device. For Android emulators, the host loopback address may differ from `localhost`; use the correct emulator networking address for the development setup.

## 10.5 Configuration notes

- Keep the base URL environment-specific; do not bake a production URL into source.
- Use HTTPS for deployed environments.
- Rotate and externalize the datasource credentials currently present in the tracked `application.properties`; keep real values out of source control.
- `application.properties.example` is the backend configuration reference and should contain placeholders only.
- `spring.jpa.hibernate.ddl-auto=none` means the backend does not provision schema changes.
- If an API contract changes, update and test both Flutter clients that consume it.

# 11. Testing and Validation

Run commands from the relevant project directory:

```powershell
# Admin Flutter (run in SHUBUS-ADMIN/frontend)
flutter analyze
flutter test

# Backend (run in SHUBUS-ADMIN/backend)
.\mvnw.cmd test

# Student Flutter (run in SHUBUS-STUDENT/frontend)
flutter analyze
flutter test
```

The checked-in tests cover Admin route/assignment refresh and model/service behavior, backend booking/seat/route/assignment rules, and Student booking-window and route-model behavior. Add regression tests to the owning project when modifying a shared workflow.

# 12. Troubleshooting

| Symptom | Checks |
|---|---|
| Flutter app cannot reach API | Confirm backend is running; check the configured `API_BASE_URL`, port, device network, firewall, and emulator-specific host address |
| Student app says API base URL is missing | Start it with `--dart-define=API_BASE_URL=http://<host>:8081` |
| Admin app calls an unexpected host | Explicitly override the Admin fallback with `--dart-define=API_BASE_URL=...` |
| Backend fails during startup | Check Java 21, Maven output, PostgreSQL reachability, datasource settings, and port availability |
| Admin route codes are missing | Verify route records and the API response; the UI does not infer a code from a route number |
| Assignment list is empty | Check the selected date range, assignment records, student eligibility, route AC type, and backend response |
| Seats are unavailable or booking is rejected | Check the booking window, assignment/shuttle availability, student active status, existing booking, seat status, and current server time |
| Booking does not appear after a change | Refresh the screen and inspect the API response; distinguish an empty booking from an HTTP/network error |

# 13. Safe Modification Guide

1. Identify whether the behavior belongs to Admin UI, Student UI, backend policy, or more than one layer.
2. Preserve the shared JSON contract unless a coordinated migration is intended.
3. For API changes, update the controller/service/DTO and all client repository/service parsers and screens that consume the affected fields.
4. Keep booking eligibility and seat allocation rules enforced by the backend; client-side checks are only for user experience.
5. Preserve route-code semantics and current Allowed Routes persistence as route-code strings unless a deliberate data migration is planned.
6. Test date/time behavior in `Asia/Kolkata`, including cutoff boundaries and date changes.
7. Do not edit generated Flutter build output, Maven `target/`, caches, or local runtime configuration as part of a source change.
8. Keep database credentials and real student/employee data out of source, logs, tests, and documentation.

# 14. Developer Handover

## 14.1 First files to inspect

| Task | Start with |
|---|---|
| Change Admin API calls | `SHUBUS-ADMIN/frontend/lib/services/route_service.dart` |
| Change Admin route fields | `SHUBUS-ADMIN/frontend/lib/models/route_model.dart`, `route_form.dart`, and backend `RouteController` |
| Change assignment behavior | `AfternoonRouteAssignmentController`, `AfternoonScheduleService`, and the two assignment/dashboard screens |
| Change student API behavior | `SHUBUS-STUDENT/frontend/lib/features/student_repository.dart` and backend controller/service |
| Change booking rules | Backend `BookingService`, `SeatService`, `BookingTimeRules`, `SeatLayout`, and `ShuttleSlotRules` |
| Change Student booking UI | `student_dashboard_screen.dart`, `seat_selection_screen.dart`, and `bookings_screen.dart` |
| Change database mapping | Backend model/repository and the database owner's schema/migration workflow |

## 14.2 Key maintenance principles

- PostgreSQL is the shared source of persisted routes, assignments, profiles, and bookings.
- Backend rules govern booking eligibility and seat availability.
- Admin and Student are separately built and configured clients of the same API.
- API DTOs and Flutter models must remain compatible.
- Database schema ownership is external to Hibernate auto-DDL.
- Identifier-only sign-in is a current prototype limitation, not a production security control.

## Final summary

**SHUBUS Admin configures and monitors transport data, SHUBUS Student consumes transport and booking services, and the shared Spring Boot API mediates all application data through PostgreSQL.**
