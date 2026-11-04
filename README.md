# 🚌 SHUBUS
### Campus shuttle booking, made clearer for every ride.

**A connected student reservation and transport administration platform.**

[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter&logoColor=white)](https://flutter.dev) [![Spring Boot](https://img.shields.io/badge/Spring%20Boot-Java-6DB33F?logo=springboot&logoColor=white)](https://spring.io/projects/spring-boot) [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Neon-4169E1?logo=postgresql&logoColor=white)](https://neon.tech)

<p align="center">
  <img src="https://github.com/user-attachments/assets/528c53d6-c466-474d-bc13-faa880d63e90" alt="SHUBUS hero image" width="900"/>
</p>

<p align="center">
  **Student App** · **Admin App** · **One shared service**
</p>

---

## A better view of the campus ride

SHUBUS brings shuttle information and reservations into a single mobile experience. Students can check the transport details associated with their profile, explore afternoon route availability, choose an available seat, and manage their booking. Transport administrators can maintain route information and daily assignments, then review schedules and dashboard summaries.

The repository brings the two experiences together through a Flutter launcher. A Spring Boot API provides shared application behavior and connects the clients to PostgreSQL.

> **One system, two audiences:** the Student experience helps riders plan; the Admin experience helps transport staff organize service.

### Current service rules

- Bookings for a travel date open at **7:30 PM the previous day** and close at **1:45 PM on the travel day** (India time).
- Seats are zoned: rows 1-5 for girls, row 6 reserved for admin/staff and unavailable to students, and rows 7-11 for boys. After booking, the student's own seat is highlighted in a read-only bus map.
- Shuttle slots are sequential and can be extended beyond the defaults (Alandur `A1`-`A5`, Velachery `V1`-`V3`, Sholinganallur `S1`, Tambaram `T1`); the Admin UI supports slots through number 99.
- AC students see AC shuttles (`A`, `V`, `S`); Non-AC students see Non-AC shuttles (`T`). Regular routes must match the student's transport profile and morning-route eligibility.

## The experience

### Start in the right place

<p align="center">
  <img src="https://github.com/user-attachments/assets/2ea27881-2852-4c6b-af4b-f8df42fee330" alt="SHUBUS app selection screen" width="260"/>
</p>

<p align="center">
  **01 · Choose an experience** — Enter the Student or Admin app from the SHUBUS launcher.
</p>

### For students

Students enter through the host application's identity flow and use the registration number supplied to SHUBUS to load their transport profile. The experience is organized around the information and actions needed to plan a ride.

<table>
<tr>
<td align="center">
<strong>02 · Your transport</strong><br/>
<img src="https://github.com/user-attachments/assets/e08d6430-cd02-495e-9bb6-7403a800459a" width="190" alt="Student transport profile"/><br/>
Assigned route and transport profile
</td>
<td align="center">
<strong>03 · Explore availability</strong><br/>
<img src="https://github.com/user-attachments/assets/45c330f5-c37e-4672-8f7e-e4e4ff2c9ceb" width="190" alt="Afternoon route availability"/><br/>
Afternoon service for a selected date
</td>
</tr>
</table>

<p align="center">
<strong>05 · Pick a seat</strong><br/>
Available, selected, booked and restricted states
</p>

<p align="center">
<img src="https://github.com/user-attachments/assets/a4ff4ab7-89dc-48c2-950b-515e342381f0" width="150" alt="Seat selection screen"/>
<img src="https://github.com/user-attachments/assets/b3768b7a-28a7-4944-8883-1d3e9848d5bc" width="150" alt="Seat booking state"/>
<img src="https://github.com/user-attachments/assets/4b1bd609-3d8c-43d3-9785-b515e342381f0" width="150" alt="Seat booking screen"/>
<img src="https://github.com/user-attachments/assets/3d0f7888-451e-4c47-b473-b23e525597e8" width="150" alt="Seat selection details"/>
</p>

### For transport administrators

The Admin app provides operational tools for route and assignment management. Route records describe services available to the system; date-based afternoon assignments determine what is offered to students. Dashboard and schedule views bring daily operations together.

<table>
<tr>
<td align="center">
<strong>01 · Admin access</strong><br/>
<img src="https://github.com/user-attachments/assets/d91c717d-1d1f-490d-a897-82cf365ec6f1" width="190" alt="Admin sign in"/>
</td>
<td align="center">
<strong>02 · Daily overview</strong><br/>
<img src="https://github.com/user-attachments/assets/bd40e577-2ec5-41da-8403-1b1b38d51848" width="190" alt="Admin operations dashboard"/>
</td>
</tr>
</table>

<table>
<tr>
<td align="center">
<strong>04 · Organize service</strong><br/>
<img src="https://github.com/user-attachments/assets/08ffde55-7fc2-4ed3-80b9-a46d9473258e" width="190" alt="Afternoon assignments"/>
</td>
<td align="center">
<strong>05 · Review the day</strong><br/>
<img src="https://github.com/user-attachments/assets/8ad38c98-c887-473d-8008-bca7858df9db" width="130" alt="Schedule view"/>
<img src="https://github.com/user-attachments/assets/f4c36c09-0c45-4fe2-9c93-8517257e7c19" width="130" alt="Schedule details"/>
</td>
<td align="center">
<strong>06 · Set route and shuttle slots</strong><br/>
<img src="https://github.com/user-attachments/assets/4c181303-3e77-4fd3-8cc1-7c873e7e72ae" width="190" alt="Assignment editor"/>
</td>
</tr>
</table>

> **Screenshot note:** Additional empty, loading, validation and success states can help explain the complete experience. Do not use real student personal information in screenshots.

## How SHUBUS fits together

```mermaid
flowchart LR
  subgraph App[Flutter application]
    Launcher[SHUBUS launcher]
    Student[Student experience]
    Admin[Admin experience]
    Launcher --> Student
    Launcher --> Admin
  end
  Student -->|HTTP / JSON| API[Spring Boot REST API]
  Admin -->|HTTP / JSON| API
  API --> Services[Business services]
  Services --> Repositories[Spring Data repositories]
  Repositories --> DB[(PostgreSQL · Neon)]
```

The clients present the user experience. The API owns shared workflow rules and persistence operations. Database entities represent persistent records, repositories query them, and services coordinate actions such as availability, booking, and assignment management.

## What the system supports

| Student services | Administration | Shared platform |
|---|---|---|
| Student and transport profile lookup | Admin sign-in and dashboard | Flutter launcher with Student/Admin entry points |
| Afternoon route availability by date | Route creation and maintenance | Spring Boot REST API |
| Seat availability and seat selection | Date-specific afternoon assignments | PostgreSQL persistence via Spring Data JPA |
| Create, view and cancel bookings | Schedule and route operations | Centralized booking, date and shuttle-slot rules |

Backend source also includes bus registration and route-to-bus API components. The supplied database reference does not confirm those tables in the live catalog, so they are described as code areas rather than guaranteed deployed schema.

## Data at a glance

The documented database is PostgreSQL hosted on Neon. The supplied database reference reports six catalog tables from an earlier export: `students`, `student_transport_profiles`, `routes`, `afternoon_route_assignments`, `bookings`, and `admin_users`. It marks that export as **partially verified**: several column positions are missing, and bus-related source entities are not confirmed in the catalog.

See [SDC.md](SDC.md#database-reference-and-data-model) for table notes, relationships, known gaps and safe schema verification queries.

## Technology

- **Mobile and app UI:** Flutter / Dart
- **API:** Java 21, Spring Boot, Spring MVC
- **Persistence:** Spring Data JPA / Hibernate
- **Database:** PostgreSQL (Neon deployment reference)
- **Client transport:** HTTP with JSON payloads

## Repository map

```text
SHUBUS-FINAL/
├── frontend/              # Combined launcher application
│   └── lib/                # Entry point and app selection screen
├── frontend-student/       # Student Flutter module
│   └── lib/features/       # Profile, routes, bookings, seats, dashboard
├── frontend-admin/        # Admin Flutter module
│   └── lib/                # Login, dashboard, routes and assignments
└── backend/                # Spring Boot REST API and persistence layer
    └── src/main/java/      # Controllers, DTOs, entities, repositories, services
```

## Project documentation

- **[SDC](SDC.md)** — detailed technical handover, application/file map, workflows, API contracts, database status, configuration and operations.
- **[Database reference](DBREF.md)** — the supplied SHUBUS database reference is a partial schema guide. Its definitions should be verified against the intended live database before schema work.

## Getting the application running

The combined launcher is in `frontend/`; the API is in `backend/`. The backend expects a pre-provisioned PostgreSQL schema and uses environment variables for database connection configuration. Setup details and configuration touchpoints are in [SDC.md](SDC.md#local-development-and-configuration).

<details>
<summary><strong>Local developer quick start</strong></summary>

With Java 21 and Flutter installed, configure `SHUBUS_DB_URL`, `SHUBUS_DB_USERNAME`, and `SHUBUS_DB_PASSWORD` locally, then start the API:

```powershell
cd backend
.\mvnw.cmd spring-boot:run
```

Fetch Flutter dependencies and launch the combined app:

```powershell
cd frontend
flutter pub get
flutter run
```

The backend example binds to port `8081`. The clients' API base URLs must point to an address reachable from the selected device or emulator. Do not commit database credentials.

</details>

---

<p align="center">

### SHUBUS

**Know the service. Choose your ride.**

*Student reservations and transport operations, connected in one platform.*

</p>
