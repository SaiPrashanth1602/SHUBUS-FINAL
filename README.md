<div align="center">

# 🚌 SHUBUS Admin

### Route, assignment, and transport operations for SHUBUS

**Admin Flutter app and shared REST API for the SHUBUS Student app.**

<p>
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Java-21-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white" alt="Java 21" />
  <img src="https://img.shields.io/badge/Spring_Boot-6DB33F?style=for-the-badge&logo=springboot&logoColor=white" alt="Spring Boot" />
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
</p>

**Admin Flutter** &nbsp; → &nbsp; **SHUBUS REST API** &nbsp; ← &nbsp; **Student Flutter**

</div>

---

## About

SHUBUS Admin provides transport administrators with tools to maintain routes and date-specific afternoon assignments, and review the dashboard and schedule. This repository also contains the Spring Boot API used by both the Admin and Student applications.

The Admin and Student apps are separate Flutter projects. They do not call each other directly: each sends HTTP requests to the shared backend, which applies server-side rules and persists data through PostgreSQL.

## Features

- Sign in using an employee ID.
- Create, view, update, and remove transport routes.
- Maintain route number, route code, route name, AC type, and allowed route codes.
- Create, edit, remove, and browse date-specific afternoon route assignments.
- Review dashboard and date-based schedule/capacity information.
- Provide the shared API for Student profiles, route discovery, seat availability, and bookings.

## Architecture

```text
┌────────────────────────┐          ┌──────────────────────┐
│ SHUBUS Admin Flutter   │ ───────► │                      │
└────────────────────────┘          │ Spring Boot REST API │ ───────► PostgreSQL
                                    │     port 8081        │
┌────────────────────────┐          │                      │
│ SHUBUS Student Flutter │ ───────► │                      │
└────────────────────────┘          └──────────────────────┘
```

## Repository layout

```text
SHUBUS-ADMIN/
├── backend/   Spring Boot API, JPA entities, services, and tests
├── frontend/  Admin Flutter application
├── README.md  Admin quick start
└── SDC.md     Combined Admin, Student, and backend handover
```

## Technology

| Component | Stack |
|---|---|
| Admin app | Flutter, Dart, Material, `http` |
| Shared API | Java 21, Spring Boot, Spring MVC, Spring Data JPA |
| Database | PostgreSQL |
| Backend build | Maven Wrapper |

## Run locally

### Prerequisites

- Flutter SDK and a supported emulator or device.
- Java 21.
- PostgreSQL database access and environment-specific credentials.

### 1. Start the backend

From this repository root, configure your local datasource settings in the shell, then start Spring Boot:

```powershell
Set-Location backend
$env:SPRING_DATASOURCE_URL = 'jdbc:postgresql://<host>:5432/<database>?sslmode=require'
$env:SPRING_DATASOURCE_USERNAME = '<database-user>'
$env:SPRING_DATASOURCE_PASSWORD = '<database-password>'
.\mvnw.cmd spring-boot:run
```

The default server port is `8081`. Check API reachability at `GET http://localhost:8081/api/health`.

### 2. Run the Admin app

In a second terminal, from the repository root:

```powershell
Set-Location frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<backend-host>:8081
```

Set `<backend-host>` to an address reachable from the selected device. On a physical phone, use the development computer's LAN address; emulator host networking may use a special address. The Admin app has a development fallback URL, so pass `API_BASE_URL` explicitly when connecting to another backend.

## Validation commands

```powershell
# Admin Flutter app (from frontend/)
flutter analyze
flutter test

# Backend (from backend/)
.\mvnw.cmd test
```

## Security and configuration notes

- The Admin login currently sends an employee ID only; it does not create a token-based authenticated session or authorize API requests. Treat it as account lookup, not a security boundary.
- The checked-in backend `application.properties` contains datasource credentials. Rotate those credentials and move them to environment-specific secret storage before sharing or deploying this repository. Do not copy credentials into this README, tests, logs, or screenshots.
- Hibernate schema auto-generation is disabled (`ddl-auto=none`). Database schema changes must use the database owner's migration process.
- Use HTTPS and a reviewed authentication/authorization design for deployed environments.

## System documentation

See [`SDC.md`](SDC.md) for the combined system architecture, Admin and Student project maps, API contract, booking rules, configuration, troubleshooting, and developer handover.

---

<div align="center">

**One shared API for SHUBUS transport administration and student bookings.**

</div>
