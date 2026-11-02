# SHUBUS
## Database Reference for SDC

**PostgreSQL on Neon · Spring Boot / JPA · Student and Admin shuttle-booking workflows**

## Purpose
Give SDC a single reference for SHUBUS database facts when it prepares or updates the project README files, SDC/system documentation, backend code, and database-related explanations.

## Accuracy status: PARTIALLY VERIFIED
This PDF combines the user's latest Neon `information_schema` column export with previously confirmed SHUBUS catalog notes. The pasted export has gaps in ordinal positions for some tables and omits some columns. It is not a complete schema dump. Missing facts are explicitly marked as unverified; SDC must not invent them.

> **Security:** Do not include database passwords or full secret connection strings in documentation or source control.

## 1. Database Overview

| Item | Known information |
|---|---|
| Database engine / hosting | PostgreSQL hosted on Neon. |
| Backend | Java Spring Boot using JPA/Hibernate. |
| Schema generation | Example configuration uses `spring.jpa.hibernate.ddl-auto=none`. Do not assume Hibernate creates or updates tables. |
| Connection environment variables | `SHUBUS_DB_URL`, `SHUBUS_DB_USERNAME`, `SHUBUS_DB_PASSWORD`. Names only; never store their values here. |
| Confirmed tables in earlier catalog export | `admin_users`, `afternoon_route_assignments`, `bookings`, `routes`, `student_transport_profiles`, `students`. |
| Tables mentioned by source-code notes but not confirmed in that catalog export | `buses`, `bus_allowed_routes`, `mock_bus_registrations`. Verify existence in live Neon before relying on them. |

## 2. Column Inventory from the Latest User-Provided Export

The following definitions are transcribed from the supplied `information_schema` output. “Not present in supplied export” means we do not know the column definition from this message; it does not prove that the column is absent from the database.

### `admin_users`

| Column / position | Type | Nullable | Default |
|---|---|---:|---|
| `id` | bigint (`int8`) | NO | — |
| `emp_id` | character varying (`varchar`) | NO | — |
| `password_hash` | character varying (`varchar`) | NO | — |
| `active` | boolean (`bool`) | NO | `true` |

### `afternoon_route_assignments`

| Column / position | Type | Nullable | Default |
|---|---|---:|---|
| `id` | bigint (`int8`) | NO | `nextval('afternoon_route_assignments_id_seq'::regclass)` |
| `route_id` | bigint (`int8`) | NO | — |
| `assignment_date` | date | NO | — |
| `assignment_type` | character varying (`varchar`) | NO | — |
| `shuttle_group` | character varying (`varchar`) | YES | — |

### `bookings`

| Column / position | Type | Nullable | Default |
|---|---|---:|---|
| `id` | bigint (`int8`) | NO | — |
| `student_id` | bigint (`int8`) | NO | — |
| Assignment link column at ordinal position 3 | Not present in supplied export | ? | Unverified |
| `booking_date` | date | NO | — |
| `seat_number` | character varying (`varchar`) | NO | — |
| Ordinal position 6 | Not present in supplied export | ? | Unverified |
| `booked_at` | timestamp without time zone | NO | `CURRENT_TIMESTAMP` |
| Ordinal position 8 | Not present in supplied export | ? | Unverified |
| `afternoon_assignment_id` | bigint (`int8`) | NO | — |

### `routes`

| Column / position | Type | Nullable | Default |
|---|---|---:|---|
| `id` | bigint (`int8`) | NO | `nextval('routes_id_seq'::regclass)` |
| `route_number` | character varying (`varchar`) | NO | — |
| `route_name` | character varying (`varchar`) | NO | — |
| `ac_type` | character varying (`varchar`) | NO | `'NON_AC'::character varying` |
| `allowed_routes` | ARRAY (`_varchar` / `varchar[]`) | NO | `ARRAY[]::character varying[]` |
| `default_afternoon` | boolean (`bool`) | NO | `false` |
| `route_code` | character varying (`varchar`) | NO | — |

### `student_transport_profiles`

| Column / position | Type | Nullable | Default |
|---|---|---:|---|
| `id` | bigint (`int8`) | NO | — |
| `student_id` | bigint (`int8`) | NO | — |
| `morning_route_number` | character varying (`varchar`) | NO | — |
| `ac_type` | character varying (`varchar`) | NO | — |
| Ordinal position 5 | Not present in supplied export | ? | Unverified |
| `morning_route_name` | character varying (`varchar`) | NO | — |

### `students`

| Column / position | Type | Nullable | Default |
|---|---|---:|---|
| `id` | bigint (`int8`) | NO | `nextval('students_id_seq'::regclass)` |
| `reg_no` | character varying (`varchar`) | NO | — |
| `name` | character varying (`varchar`) | NO | — |
| `password_hash` | character varying (`varchar`) | NO | — |
| `active` | boolean (`bool`) | NO | `true` |
| `gender` | character varying (`varchar`) | NO | — |

## 3. Confirmed Relationships and Constraints from Earlier Catalog Notes

These facts came from a previous catalog summary and should be rechecked against current Neon metadata before schema migrations or code changes.

### Primary keys
The six confirmed base tables were reported to have primary keys on `id`. Exact identity/sequence behavior is not uniform: the latest export shows defaults on several IDs but no defaults on others. Do not assume every ID is generated automatically.

### Foreign keys

| Referencing column | Referenced column | Known delete action |
|---|---|---|
| `afternoon_route_assignments.route_id` | `routes.id` | RESTRICT |
| `bookings.student_id` | `students.id` | RESTRICT |
| `student_transport_profiles.student_id` | `students.id` | CASCADE |
| `bookings.afternoon_assignment_id` | `afternoon_route_assignments.id` | Not confirmed in the supplied notes |

### Unique constraints reported previously

| Table / columns | Known rule |
|---|---|
| `admin_users.emp_id` | Unique |
| `students.reg_no` | Unique |
| `student_transport_profiles.student_id` | Unique |
| `routes.route_number` | Unique |
| `routes.route_code` | Unique |
| `afternoon_route_assignments(assignment_date, route_id)` | Unique |
| `bookings(afternoon_assignment_id, booking_date, seat_number)` | Unique |
| `bookings(student_id, booking_date)` | Unique |

Previously observed booking index names: `unique_student_booking_per_day` on `(student_id, booking_date)`, and `unique_booking_seat` on `(afternoon_assignment_id, booking_date, seat_number)`. Recheck exact index definitions.

### Reported allowed values
`afternoon_route_assignments.assignment_type`: `REGULAR` / `SHUTTLE`; `routes.ac_type` and `student_transport_profiles.ac_type`: `AC` / `NON_AC`; `students.gender`: `GIRL` / `BOY`. These are reported allowed values, not proof of PostgreSQL enum types. Inspect check constraints and column types.

RLS was reported disabled on the six tables in the earlier export. Recheck current RLS state before making security claims.

## 4. Business Rules Known from Backend Review

- Student exists and is active.
- Student has a transport profile / morning route.
- Afternoon assignment exists and assignment date matches booking date.
- Booking window is open.
- Shuttle availability is checked for SHUTTLE assignments.
- Seat number is valid and is not a faculty seat.
- Student is eligible for the seat category.
- For REGULAR assignments, AC type and allowed route code are checked.
- Student cannot have more than one booking per date.
- Requested seat must be available.

Inspect current backend source before modifying these rules. Database unique constraints are important safeguards against duplicate student bookings and duplicate seat bookings.

## 5. Route Eligibility Data

Prior notes state that `routes.allowed_routes` stores verified morning-to-afternoon route eligibility codes, with 167 verified pairs recorded at that time. Historical example: route code `1314` (A1/CMBT) had allowed routes `{1306, 1308}`; Route 12 had route code `1306`. This is historical context only, not guaranteed current data. Earlier notes said legacy `afternoon_route_eligibility` and its backup were removed; verify the current catalog before using or recreating them.

## 6. Bus `flag` Issue — Unresolved

A bus-related field called `flag` was changed to `FALSE`, but the bus still appeared in the app. The current export does not show any `flag` column in the six listed tables. It may exist in another table or may not be part of the current schema; inspect the live catalog before drawing conclusions.

- Find every live column named `flag`.
- Confirm the exact table and bus row, then read its current value.
- Verify the backend is connected to the same Neon database that was edited.
- Identify the API endpoint feeding the screen where the bus appears.
- Inspect the endpoint's repository/service query and determine whether it filters on this field.
- Compare the direct API response with the Flutter UI. If API returns the bus, investigate database/environment/query; if API excludes it, investigate Flutter state/cache or another endpoint.

Do not add `WHERE flag = TRUE` until the field's intended business meaning and the relevant endpoint behavior are confirmed.

## 7. Previously Identified API Endpoints

These mappings were recorded in earlier backend notes; verify current controller mappings in source.

| Method / path |
|---|
| `GET /api/health` |
| `POST /api/admin/auth/login` |
| `GET /api/admin/dashboard` |
| `GET /api/admin/routes` |
| `GET /api/admin/afternoon-routes` |
| `GET /api/admin/schedule` |
| `POST /api/auth/login` |
| `GET /api/buses` |
| `GET /api/registrations/{regNo}` |
| `GET /api/routes/{routeId}/buses` |
| `GET /api/students/{regNo}` |
| `GET /api/students/{regNo}/profile` |
| `GET /api/students/{regNo}/transport-profile` |
| `GET /api/students/{regNo}/afternoon-routes` |
| `GET /api/students/{regNo}/afternoon-routes/{assignmentId}/seats` |
| `POST /api/students/bookings` |
| `GET /api/students/{regNo}/bookings?date=YYYY-MM-DD` |
| `DELETE /api/students/{regNo}/bookings/{bookingId}` |

Security caveat: an earlier review suggested student flows may use registration-number-based access without token-based authentication. Verify current code. Do not authorize access to student data or booking changes based only on a user-supplied registration number.

## 8. Read-Only SQL to Complete the Schema

Run these against the intended Neon database. These queries inspect metadata only and do not modify application data.

### List user tables

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;
```

### List columns, types, nullability and defaults

```sql
SELECT table_schema, table_name, ordinal_position, column_name,
       data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name, ordinal_position;
```

### List constraints

```sql
SELECT ns.nspname AS schema_name, tbl.relname AS table_name,
       con.conname AS constraint_name, con.contype AS constraint_type,
       pg_get_constraintdef(con.oid, true) AS definition
FROM pg_constraint con
JOIN pg_class tbl ON tbl.oid = con.conrelid
JOIN pg_namespace ns ON ns.oid = tbl.relnamespace
WHERE ns.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY ns.nspname, tbl.relname, con.contype, con.conname;
```

### List indexes

```sql
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename, indexname;
```

### Find columns named `flag`

```sql
SELECT table_schema, table_name, column_name, data_type, udt_name,
       is_nullable, column_default
FROM information_schema.columns
WHERE lower(column_name) = 'flag'
ORDER BY table_schema, table_name;
```

## 9. Instructions for SDC

- Treat this PDF as database context, not as a replacement for the live schema or project source code.
- Inspect current JPA entities, repositories, services, controllers, configuration, and migration/schema files before proposing database changes.
- If schema notes are incomplete or conflict with code, state the discrepancy; do not guess.
- Never print, commit, or request database passwords or secret connection strings.
- Do not execute destructive SQL (`DROP`, `TRUNCATE`, broad `DELETE`, destructive `ALTER`) or modify production data without explaining impact and obtaining explicit confirmation.
- Prefer read-only inspection first. For data changes, identify the exact target row and propose a transaction/rollback plan.
- Do not invent tables, columns, status meanings, enum values, constraints, or relationships.
- Do not filter on `flag` or another status field until its meaning and affected API/UI behavior are confirmed.
- For migrations, state whether the change is additive/destructive/reversible and whether data backfilling is needed.
- When generating README files or the SDC, distinguish verified schema facts from historical notes and unresolved gaps.

## 10. Remaining Work Before Calling This the Complete Database Reference

The supplied column export has gaps: bookings ordinals 3, 6 and 8 are missing; `student_transport_profiles` ordinal 5 is missing; the export does not show the buses-related tables or a `flag` column. This does not prove those columns/tables do not exist. Provide the complete current Neon schema-only export (DDL, no data and no secrets), ideally from `pg_dump --schema-only`, plus the catalog query results for constraints and indexes. Then update this reference with exact live definitions and a verified data dictionary.
