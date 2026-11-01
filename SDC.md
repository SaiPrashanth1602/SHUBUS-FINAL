# SHUBUS — System Design and Documentation (SDC)

> **Scope:** Shared SHUBUS system documentation based on the supplied Admin and Student repository snapshots and the supplied Neon PostgreSQL catalog export.
>
> **Verification rule:** Database facts below come from the Neon catalog export. Application behavior comes from the supplied source code. Where those sources do not agree or do not establish a fact, this document marks the point as unverified instead of guessing.

## 1. System overview

SHUBUS is a campus shuttle booking system with two Flutter clients:

- **SHUBUS Admin** — route management, afternoon assignment management, and schedule/dashboard views.
- **SHUBUS Student** — student transport-profile viewing, route discovery, seat availability, booking, booking review, and cancellation.

Both clients communicate with a shared **Java Spring Boot REST API**. The backend persists application data in **PostgreSQL hosted on Neon**. The Student application does not connect directly to PostgreSQL or to the Admin application.

```text
┌────────────────────────┐          ┌────────────────────────┐
│ SHUBUS Admin (Flutter) │ ───────► │                        │
└────────────────────────┘          │                        │
                                    │ Spring Boot REST API   │ ───────► Neon PostgreSQL
┌────────────────────────┐          │                        │
│ SHUBUS Student         │ ───────► │                        │
│ (Flutter)              │          └────────────────────────┘
└────────────────────────┘
```

The supplied Admin repository contains the shared backend. The Student repository contains the Student Flutter frontend and documents the API as being hosted/maintained in the Admin repository.

## 2. Technology stack

| Layer | Technology evidenced by the repositories |
|---|---|
| Admin client | Flutter / Dart |
| Student client | Flutter / Dart |
| Backend | Java, Spring Boot, Spring Data JPA |
| HTTP API | Spring MVC REST controllers |
| Database | PostgreSQL on Neon |
| Persistence | Hibernate/JPA and Spring Data repositories |
| Password hashing utility | Spring Security Crypto `BCryptPasswordEncoder` |
| Student HTTP client | Dart `http` package |
| Admin HTTP client | Dart service using HTTP requests |

The backend `pom.xml` sets Java 21 and Spring Boot 4.1.1. The backend example configuration uses port `8081`, binds to `0.0.0.0`, and sets `spring.jpa.hibernate.ddl-auto=none`. The actual deployment/runtime values must be taken from the environment where the backend is running; do not publish database credentials.

## 3. Repository layout

### Admin repository

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

### Student repository

```text
SHUBUS-STUDENT/
└── frontend/
    ├── lib/
    │   ├── app/
    │   ├── core/
    │   └── features/
    └── test/
```

## 4. Admin application

The supplied Admin frontend includes:

- Employee-ID sign-in screen.
- Dashboard with date-based schedule/capacity information.
- Route listing and route create/edit/delete flows.
- Route code, route number, route name, AC type, and Allowed Routes editing.
- Afternoon assignment discovery and management.
- User-triggered refresh actions and loading/error states.

The Admin client configures the API base URL through `API_BASE_URL`; the source snapshot includes a local-network fallback in its Admin API config. For another machine or deployment, configure the URL for the target environment instead of relying on that fallback.

## 5. Student application

The supplied Student frontend includes:

- Student sign-in using a registration number.
- Student profile and morning-route details.
- Route browsing/search and AC type filters.
- Afternoon assignment discovery.
- Seat availability and seat selection.
- Booking confirmation, booking lookup, and cancellation.
- Loading, empty, and error states.

The Student API client reads `API_BASE_URL` through a Dart compile-time define and uses a 12-second request timeout. Run the app with a backend URL reachable from the selected emulator/device. `localhost` on a physical phone points to the phone itself, not the development computer.

## 6. Backend responsibilities and API inventory

The supplied backend separates HTTP controllers, DTOs, JPA models, repositories, services, and utility rules.

| Controller base/path | Operations evidenced in source |
|---|---|
| `GET /api/health` | Health endpoint |
| `POST /api/admin/auth/login` | Admin login |
| `GET /api/admin/dashboard` | Admin dashboard summary |
| `/api/admin/routes` | List, fetch by ID, create, update, delete routes |
| `/api/admin/afternoon-routes` | List/discover assignments; bulk create; create; update by ID; delete by ID |
| `GET /api/admin/schedule` | Schedule lookup |
| `POST /api/auth/login` | Student login endpoint |
| `GET /api/buses` | Bus listing endpoint |
| `GET /api/registrations/{regNo}` | Registration lookup endpoint |
| `GET /api/routes/{routeId}/buses` | Route-associated bus lookup endpoint |
| `GET /api/students/{regNo}` | Student lookup |
| `GET /api/students/{regNo}/profile` | Student profile response |
| `GET /api/students/{regNo}/transport-profile` | Transport profile lookup |
| `GET /api/students/{regNo}/afternoon-routes` | Eligible afternoon route discovery |
| `GET /api/students/{regNo}/afternoon-routes/{assignmentId}/seats` | Seat availability |
| `POST /api/students/bookings` | Create booking |
| `GET /api/students/{regNo}/bookings?date=YYYY-MM-DD` | Retrieve booking for a date |
| `DELETE /api/students/{regNo}/bookings/{bookingId}` | Cancel booking |

This is a controller-path inventory, not a guarantee that every endpoint is enabled or reachable in a particular deployment. Check controller annotations and request DTOs in the current source before integrating a new client.

## 7. Booking and eligibility rules in the supplied backend

The supplied `BookingService` implements the following checks during booking creation:

1. Registration number, assignment ID, booking date, and seat number must be supplied.
2. The student must exist and be active.
3. The student must have a transport profile and the configured morning route must exist.
4. The afternoon assignment must exist, and the requested booking date must equal the assignment date.
5. The booking window must be open.
6. A `SHUTTLE` assignment must pass the shuttle-availability check.
7. The seat must be valid and must not be a faculty-only seat.
8. Seat eligibility is checked against the student's `GIRL`/`BOY` category using the shared seat-layout rules.
9. For a regular assignment, the afternoon route AC type must match the student's profile AC type.
10. For a regular assignment, the afternoon route code must be included in the morning route's `allowed_routes`.
11. The service checks for an existing booking by the same student on the same date and checks seat availability before saving.

The code snapshot establishes these application checks. The exact time boundaries are defined in `BookingTimeRules` and the shuttle-specific availability rules; consult those classes before documenting particular opening/closing hours. Database unique indexes additionally enforce uniqueness for `(student_id, booking_date)` and `(afternoon_assignment_id, booking_date, seat_number)` in the catalog export.

The Admin audit report in the supplied repository describes 55 physical seats, with 50 student-bookable seats and five faculty-only seats. Treat that capacity description as source-reported behavior and re-check `SeatLayout` before changing the layout.

## 8. Neon PostgreSQL schema — catalog-confirmed tables

The supplied catalog export confirms six base tables in schema `public`:

| Table | Catalog-export estimated live rows* | Purpose inferred from column names and code |
|---|---:|---|
| `routes` | 113 | Route identity, route code/name, AC type, allowed route codes, afternoon default |
| `afternoon_route_assignments` | 229 | Dated route assignment, assignment type, optional shuttle group |
| `bookings` | 5 | Student seat bookings tied to a dated assignment |
| `students` | 2 | Student registration, name, password hash, active flag, gender |
| `student_transport_profiles` | 2 | Student morning route and AC type |
| `admin_users` | 1 | Admin employee ID, password hash, active flag |

\*Row counts are `pg_stat_user_tables.n_live_tup` estimates from the supplied export, not exact counts or a guarantee of current live contents.

### 8.1 `routes`

| Column | Type | Null? | Default/constraint from export |
|---|---|---|---|
| `id` | `bigint` | No | `routes_id_seq` default |
| `route_number` | `varchar(20)` | No | Unique |
| `route_name` | `varchar(150)` | No | — |
| `ac_type` | `varchar(10)` | No | `NON_AC`; check constraint allows `AC` or `NON_AC` |
| `allowed_routes` | `varchar[]` | No | Empty varchar array |
| `default_afternoon` | `boolean` | No | `false` |
| `route_code` | `varchar` | No | Unique |

### 8.2 `afternoon_route_assignments`

| Column | Type | Null? | Default/constraint from export |
|---|---|---|---|
| `id` | `bigint` | No | `nextval('afternoon_route_assignments_id_seq')` |
| `route_id` | `bigint` | No | FK to `routes.id`, delete restricted |
| `assignment_date` | `date` | No | — |
| `assignment_type` | `varchar(20)` | No | Check allows `REGULAR` or `SHUTTLE` |
| `shuttle_group` | `varchar(30)` | Yes | — |

Unique constraint: `(assignment_date, route_id)`.

### 8.3 `bookings`

The export provides these column definitions:

| Column | Type | Null? | Default/constraint from export |
|---|---|---|---|
| `id` | `bigint` | No | Identity |
| `student_id` | `bigint` | No | FK to `students.id`, delete restricted |
| `booking_date` | `date` | No | — |
| `seat_number` | `varchar(5)` | No | — |
| `booked_at` | `timestamp without time zone` | No | `CURRENT_TIMESTAMP` |
| `afternoon_assignment_id` | `bigint` | No | FK to `afternoon_route_assignments.id` |

**Column metadata gap:** the provided column export jumps from ordinal position 2 to 4, 5, 7, and 9 for `bookings`. Ordinal positions 3, 6, and 8 were not included in the supplied output. This document does not invent their names or definitions. The JPA model snapshot does not by itself establish the missing physical columns.

Unique indexes reported in the catalog export: `(afternoon_assignment_id, booking_date, seat_number)` and `(student_id, booking_date)`. Indexes `idx_bookings_date` and `idx_bookings_student` are also reported.

### 8.4 `students`

| Column | Type | Null? | Default/constraint from export |
|---|---|---|---|
| `id` | `bigint` | No | `students_id_seq` default |
| `reg_no` | `varchar(20)` | No | Unique |
| `name` | `varchar(100)` | No | — |
| `password_hash` | `varchar(255)` | No | — |
| `active` | `boolean` | No | `true` |
| `gender` | `varchar(10)` | No | Check allows `GIRL` or `BOY` |

### 8.5 `student_transport_profiles`

| Column | Type | Null? | Default/constraint from export |
|---|---|---|---|
| `id` | `bigint` | No | Identity |
| `student_id` | `bigint` | No | Unique; FK to `students.id`, `ON DELETE CASCADE` |
| `morning_route_number` | `varchar(20)` | No | — |
| `ac_type` | `varchar(20)` | No | Check allows `AC` or `NON_AC` |
| `morning_route_name` | `varchar(150)` | No | — |

**Column metadata gap:** ordinal position 5 was not included in the supplied export. Its name and definition remain unverified and are intentionally not guessed.

### 8.6 `admin_users`

| Column | Type | Null? | Default/constraint from export |
|---|---|---|---|
| `id` | `bigint` | No | Identity |
| `emp_id` | `varchar(50)` | No | Unique |
| `password_hash` | `varchar(255)` | No | — |
| `active` | `boolean` | No | `true` |

### 8.7 Catalog-confirmed relationships and constraints

- `afternoon_route_assignments.route_id` references `routes.id` with `ON DELETE RESTRICT`.
- `bookings.student_id` references `students.id` with `ON DELETE RESTRICT`.
- `bookings.afternoon_assignment_id` references `afternoon_route_assignments.id`.
- `student_transport_profiles.student_id` references `students.id` with `ON DELETE CASCADE`.
- Primary keys are reported on the `id` column of each of the six tables.
- `routes.route_number`, `routes.route_code`, `students.reg_no`, `admin_users.emp_id`, `student_transport_profiles.student_id`, and `(afternoon_route_assignments.assignment_date, afternoon_route_assignments.route_id)` are unique.
- Check constraints restrict route/profile AC type, assignment type, and student gender to the listed values.
- The export reports row-level security disabled and not forced on all six tables.
- The export reports no views, materialized views, triggers, custom types, or RLS policies in the queried result. This is a statement about the supplied export, not a universal guarantee about later database changes.

## 9. Important database/application alignment finding

The JPA source also contains models mapped to `buses`, `bus_allowed_routes`, and `mock_bus_registrations`. Those tables were **not among the six base tables shown by the supplied Neon catalog export**. The source also has bus/registration-related controllers and repositories.

Therefore, the supplied evidence does not establish that those three tables exist in the connected Neon database. Before using those paths in production, verify the current table list and the runtime behavior of those endpoints. The backend example sets `spring.jpa.hibernate.ddl-auto=none`, so Hibernate is not configured by that example to create missing tables automatically.

The source code and the catalog export are not perfectly reconciled yet: the `Booking` entity marks `seat_number` without `nullable = false`, while the physical catalog reports `seat_number` as `NOT NULL`; the entity also does not show all database-level uniqueness declarations. The physical catalog is authoritative for the current database schema.

## 10. Authentication and security notes

- The backend defines a `BCryptPasswordEncoder` bean and stores password hashes in `students` and `admin_users`.
- The supplied Student README says the current Student sign-in flow identifies the student by registration number only and does not establish a token-based authenticated session.
- The supplied Admin frontend uses an employee-ID login flow. Review the exact controller/service implementation before claiming a particular session/token mechanism.
- Because the catalog reports RLS disabled on all six tables, data access control must be provided by the backend/database credentials and application authorization; RLS is not currently an additional table-level protection in the supplied snapshot.
- Do not commit `.env` files, database URLs containing credentials, database passwords, student data, or generated password hashes.
- A BCrypt encoder being present does not, by itself, prove every login or registration flow is secure. Authentication, authorization, brute-force protections, secret management, and endpoint access need their own security review.

## 11. Local development

### Backend

1. Install a compatible JDK (the supplied Maven project targets Java 21).
2. Configure database environment variables locally, using the repository's example configuration as a template.
3. Ensure the active `application.properties` maps `SHUBUS_DB_URL`, `SHUBUS_DB_USERNAME`, and `SHUBUS_DB_PASSWORD` to the Spring datasource properties.
4. Run the backend from `backend/` with the Maven wrapper.
5. The example server port is `8081`; verify the actual runtime port before configuring either app.

Example environment variable names (use local values; never commit secrets):

```text
SHUBUS_DB_URL=jdbc:postgresql://<neon-host>/<database>?sslmode=require
SHUBUS_DB_USERNAME=<database-user>
SHUBUS_DB_PASSWORD=<database-password>
```

### Flutter clients

From each app's `frontend/` directory:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<reachable-backend-host>:8081
```

For the Student client, the API base URL is read from `API_BASE_URL`. For the Admin client, configure `API_BASE_URL` for the target machine/environment; do not depend on the local-network fallback outside its intended network.

## 12. Verification status and remaining work

### Confirmed from supplied artifacts

- Both Flutter repository snapshots were inspected.
- The Admin repository contains the shared Spring Boot backend.
- The Student app calls a REST API rather than connecting directly to the database.
- Six `public` base tables and their exported column/constraint/index metadata are documented above.
- Booking eligibility checks are present in the supplied backend source.
- The backend example configuration sets `ddl-auto=none`.

### Not claimed as verified

- A live end-to-end request against the currently running backend and Neon database.
- Current production API reachability or deployment environment.
- The missing `bookings` column definitions at ordinal positions 3, 6, and 8.
- The missing `student_transport_profiles` column definition at ordinal position 5.
- Whether `buses`, `bus_allowed_routes`, and `mock_bus_registrations` exist in the connected database.
- Production security posture or full authentication/authorization correctness.
- Exact current row counts; the supplied table statistics are estimates.

To close the schema gaps, rerun a column query in Neon and export the result as CSV rather than copying a partial JSON output. To verify the additional model tables, query `information_schema.tables` for all `public` base tables. End-to-end runtime verification must be performed against the deployed backend without sharing database credentials.

## 13. Source of truth order

When sources differ, use this order:

1. **Current Neon catalog** for the physical schema, constraints, indexes, and RLS state.
2. **Current backend source** for implemented API behavior and validation.
3. **Current Flutter source** for screens, API calls, and client-side behavior.
4. Repository README/audit documents as explanatory context, not a replacement for the source.

---
*Prepared from the supplied SHUBUS Admin and Student repository snapshots and Neon catalog export. Re-run verification after schema or API changes.*
