# SHUBUS Admin

Flutter admin client and shared Spring Boot backend for the SHUBUS campus shuttle booking system.

## Overview

SHUBUS has two Flutter clients—Admin and Student—that communicate with one shared Spring Boot REST API. The backend uses Spring Data JPA to access PostgreSQL hosted on Neon. The Student client does not connect directly to the Admin client or database.

```text
Admin Flutter ─────┐
                   ├──► Spring Boot REST API ───► Neon PostgreSQL
Student Flutter ───┘
```

## Features evidenced in the supplied source

- Employee-ID admin sign-in.
- Dashboard and date-based schedule/capacity views.
- Route list/create/edit/delete workflows.
- Route number, route code, route name, AC type, and Allowed Routes management.
- Afternoon route assignment discovery and management.
- User-triggered refresh and loading/error feedback.
- Shared backend endpoints used by the Student app for profile, assignment, seat, and booking operations.

## Repository structure

```text
SHUBUS-ADMIN/
├── frontend/
│   └── lib/
│       ├── main.dart
│       ├── models/
│       ├── screens/
│       ├── services/
│       └── widgets/
└── backend/
    ├── pom.xml
    └── src/main/
        ├── java/com/shubus/backend/
        │   ├── config/
        │   ├── controller/
        │   ├── dto/
        │   ├── model/
        │   ├── repository/
        │   ├── service/
        │   └── util/
        └── resources/
```

## Technology

- Flutter and Dart for the Admin client.
- Java 21 and Spring Boot 4.1.1 in the supplied Maven project.
- Spring MVC, Spring Data JPA/Hibernate, and PostgreSQL JDBC driver.
- PostgreSQL hosted on Neon.
- BCrypt password encoder bean in the backend.

## Configure the backend

The supplied example configuration names these environment variables:

```text
SHUBUS_DB_URL=jdbc:postgresql://<neon-host>/<database>?sslmode=require
SHUBUS_DB_USERNAME=<database-user>
SHUBUS_DB_PASSWORD=<database-password>
```

Configure the active `application.properties` so the Spring datasource reads those environment variables. The supplied example uses:

```properties
spring.jpa.hibernate.ddl-auto=none
spring.jpa.show-sql=false
server.address=0.0.0.0
server.port=8081
```

The actual runtime port and active configuration must be checked in the environment where the backend runs. Never commit real credentials or a database URL containing a password.

### Start the backend

From `backend/`, with a compatible JDK installed and the datasource environment configured:

```bash
./mvnw spring-boot:run
```

On Windows PowerShell:

```powershell
.\mvnw.cmd spring-boot:run
```

The example port is `8081`. Check `GET /api/health` to confirm the service is responding; a health response alone does not prove every database-backed endpoint works.

## Configure and run the Admin Flutter app

From `frontend/`:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<reachable-backend-host>:8081
```

Set the API URL to an address reachable from the emulator/device. The supplied Admin `ApiConfig` includes a local-network fallback; use an explicit `API_BASE_URL` override when running on another machine or network.

## Important backend API paths

| Path | Purpose evidenced in source |
|---|---|
| `GET /api/health` | Health endpoint |
| `POST /api/admin/auth/login` | Admin login |
| `GET /api/admin/dashboard` | Dashboard summary |
| `/api/admin/routes` | Route CRUD operations |
| `/api/admin/afternoon-routes` | Afternoon assignment list/create/update/delete and bulk creation |
| `GET /api/admin/schedule` | Date-based schedule lookup |
| `/api/students/{regNo}/afternoon-routes` | Student afternoon route discovery |
| `/api/students/{regNo}/afternoon-routes/{assignmentId}/seats` | Seat availability |
| `POST /api/students/bookings` | Booking creation |
| `GET /api/students/{regNo}/bookings?date=YYYY-MM-DD` | Booking lookup |
| `DELETE /api/students/{regNo}/bookings/{bookingId}` | Booking cancellation |

This is a quick inventory, not a complete OpenAPI contract. Inspect each controller and DTO for exact request/response fields and validation.

## Database source of truth

The supplied Neon catalog export confirms six tables in `public`:

- `routes`
- `afternoon_route_assignments`
- `bookings`
- `students`
- `student_transport_profiles`
- `admin_users`

The export reports primary/foreign keys, unique constraints/indexes, check constraints, and RLS disabled on those six tables. See [`SDC.md`](SDC.md) for the full catalog-based table definitions and relationships.

### Schema alignment warnings

- The supplied backend source contains JPA models mapped to `buses`, `bus_allowed_routes`, and `mock_bus_registrations`, but those tables were not among the six base tables in the supplied Neon catalog export. Their existence in the connected database has not been established by that export.
- The `bookings` column export omits ordinal positions 3, 6, and 8. The `student_transport_profiles` export omits ordinal position 5. Their names/definitions are not guessed in the SDC.
- The physical database reports `bookings.seat_number` as `NOT NULL`; the supplied `Booking` entity does not mark that field `nullable = false`. The database catalog is authoritative for physical nullability.
- The example config uses `spring.jpa.hibernate.ddl-auto=none`; do not assume Hibernate will create missing tables.

Before adding or changing entities, verify the live Neon schema and use an explicit reviewed migration where schema changes are required.

## Booking logic

The supplied backend checks that the student exists and is active, has a transport profile, chooses an assignment/date match, books during the allowed window, uses a valid non-faculty seat, complies with the gender seat-layout rules, and—on regular assignments—matches AC type and route-code eligibility. It also checks one booking per student/date and seat availability. Shuttle assignments use a separate availability check.

The catalog export additionally reports unique indexes for `(student_id, booking_date)` and `(afternoon_assignment_id, booking_date, seat_number)`. Check the current source rules before changing booking behavior.

## Security notes

- Password hashes are represented in the schema; a BCrypt encoder bean exists in the backend.
- The Student sign-in flow described in the supplied Student README uses registration number only and does not create a token-based authenticated session.
- Do not assume the presence of a password encoder proves all authentication paths are secure.
- RLS is reported disabled on all six catalog-confirmed tables. Do not rely on RLS as a protection layer in the current supplied snapshot.
- Do not commit database credentials, real student data, tokens, or password hashes.

## Validation

From `frontend/`:

```bash
flutter analyze
flutter test
```

From `backend/`:

```bash
./mvnw test
```

Use `.\mvnw.cmd test` on Windows. These are the commands to validate the current checkout; prior test results in an audit note are not a guarantee that a different or newer checkout still passes.

## Shared system documentation

- [`SDC.md`](SDC.md) — system architecture, endpoint inventory, booking rules, Neon catalog schema, security notes, and unresolved verification items.
- Student app README: see the SHUBUS Student repository.

---
*Documentation is based on the supplied repository snapshot and Neon catalog export. Confirm runtime configuration and schema again after changes.*
