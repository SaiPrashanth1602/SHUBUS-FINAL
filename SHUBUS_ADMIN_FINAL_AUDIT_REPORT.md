# SHUBUS Admin Implementation Audit

## Summary

Implemented the approved Admin App improvements while retaining the existing Flutter, Spring Boot, and PostgreSQL contracts. The work covers route-code editing and Allowed Routes display, assignment discovery and manual refresh, dashboard loading, student-bookable seat capacity, and clearer API error responses.

## Findings and changes

### Routes and Allowed Routes

- The route model and API already expose route codes; Allowed Routes are persisted as route-code strings in the existing mapping. The Flutter selector now displays route codes, searches by them, restores saved selections, and shows selected routes below the Allowed Afternoon Routes heading.
- A route whose response has a missing or blank route code is explicitly marked unavailable and cannot be selected as if its bus number were a route code. Legacy saved values are resolved to a route code only when a matching route is available; values are not guessed or rewritten.
- Route create and edit requests now include the route code. The backend rejects blank and duplicate route codes (case-insensitive). An update that omits the code preserves the existing value; explicitly supplied fields are validated before saving.
- The existing Allowed Routes API contract uses route-code strings rather than route IDs. No new mapping or identifier contract was introduced.
- A prior local API observation returned route records without route codes. The source flow now includes the response field, but the local API was unavailable during this implementation, so the current running server and its records could not be rechecked. Records that still lack codes remain unavailable in the UI.

### Assignments and dashboard refresh

- Assignment discovery uses the existing date-range endpoint to include future assignments through a 365-day horizon (or the selected range if wider), avoiding per-day requests.
- Existing assignments remain visible by default; Assign More stays in the same screen. The manual refresh control is in the assignment screen header, not in the Add Buses sheet, and preserves the current form/filter state. Assignment database actions retain action-specific loading feedback.
- The dashboard uses one range request for the next 90 days and loads detailed schedule data only for the first scheduled date. Returning to the dashboard tab no longer triggers an automatic refresh.
- Routes, assignments, and the dashboard provide explicit refresh actions. Refresh is user-initiated; no timer-based polling or background refresh was added.

### Seat capacity and errors

- Student-bookable capacity is calculated from the shared seat layout: 50 seats are student-bookable and five of the 55 physical seats remain faculty-only. The physical layout and booking restriction were not changed.
- Backend validation, not-found, conflict, unsupported-method/media, and unexpected errors now return appropriate status codes. Unexpected failures are logged and return a generic message instead of exposing internal details. Existing login validation response behavior is preserved.

## Database and compatibility

- No PostgreSQL schema changes, migrations, database writes, or live database queries were performed.
- The existing route-code and Allowed Routes persistence model was retained. No existing mappings were intentionally discarded or migrated.
- There are no checked-in SQL schema/migration files establishing another mapping contract. Runtime database contents and production API behavior remain unverified.

## Files currently changed in the worktree

The worktree was already dirty when this verification started. The list below describes files that are modified or untracked at final inspection; it is not an attribution of every change to this verification run.

Backend production files:

- `backend/src/main/java/com/shubus/backend/BackendApplication.java`
- `backend/src/main/java/com/shubus/backend/controller/AfternoonRouteAssignmentController.java`
- `backend/src/main/java/com/shubus/backend/controller/RouteController.java`
- `backend/src/main/java/com/shubus/backend/controller/GlobalExceptionHandler.java`
- `backend/src/main/java/com/shubus/backend/controller/BusRegistrationController.java`
- `backend/src/main/java/com/shubus/backend/controller/StudentController.java`
- `backend/src/main/java/com/shubus/backend/controller/TransportProfileController.java`
- `backend/src/main/java/com/shubus/backend/dto/AdminDashboardResponse.java`
- `backend/src/main/java/com/shubus/backend/dto/AdminLoginRequest.java`
- `backend/src/main/java/com/shubus/backend/dto/LoginRequest.java`
- `backend/src/main/java/com/shubus/backend/dto/RouteResponse.java`
- `backend/src/main/java/com/shubus/backend/dto/StudentProfileResponse.java` (untracked)
- `backend/src/main/java/com/shubus/backend/repository/AfternoonRouteAssignmentRepository.java`
- `backend/src/main/java/com/shubus/backend/repository/RouteRepository.java`
- `backend/src/main/java/com/shubus/backend/service/AdminAuthService.java`
- `backend/src/main/java/com/shubus/backend/service/AdminDashboardService.java`
- `backend/src/main/java/com/shubus/backend/service/AfternoonScheduleService.java`
- `backend/src/main/java/com/shubus/backend/service/AuthService.java`
- `backend/src/main/java/com/shubus/backend/service/BookingService.java`
- `backend/src/main/java/com/shubus/backend/service/SeatService.java`
- `backend/src/main/java/com/shubus/backend/service/StudentAfternoonRouteService.java`
- `backend/src/main/java/com/shubus/backend/util/SeatLayout.java`
- `backend/src/main/resources/application.properties.example`

Frontend production files:

- `frontend/lib/models/route_model.dart`
- `frontend/lib/screens/admin_dashboard_screen.dart`
- `frontend/lib/screens/admin_login_screen.dart`
- `frontend/lib/screens/afternoon_assignment_screen.dart`
- `frontend/lib/screens/routes_screen.dart`
- `frontend/lib/services/api_config.dart` (untracked)
- `frontend/lib/services/route_service.dart`
- `frontend/lib/widgets/route_form.dart`

Test files:

- Backend: `AfternoonRouteAssignmentControllerTest.java`, `GlobalExceptionHandlerTest.java`, `RouteControllerMvcTest.java`, `RouteControllerTest.java`, `AdminDashboardServiceTest.java`, `BookingServiceTest.java`, `SeatServiceTest.java`, `StudentAfternoonRouteServiceTest.java`, and `SeatLayoutTest.java`.
- Flutter: `widget_test.dart`, `route_form_test.dart`, `route_model_test.dart`, `route_service_test.dart`, `afternoon_assignment_refresh_test.dart`, `dashboard_refresh_test.dart`, and `route_screen_refresh_test.dart`.

Other tracked worktree changes include `frontend/lib.zip` and six files under `frontend/android/.gradle/`. No Android manifest, signing, app Gradle, or release configuration file was changed. Dependency manifests and lockfiles were not intentionally changed.

## POST-IMPLEMENTATION AUTOMATED VERIFICATION

### Commands executed and results

- `flutter analyze` from `frontend/`: **passed**, no issues found.
- `flutter test` from `frontend/`: **passed**, all 22 tests.
- `.\mvnw.cmd -Dtest=AfternoonRouteAssignmentControllerTest,RouteControllerTest,RouteControllerMvcTest,GlobalExceptionHandlerTest,SeatLayoutTest,SeatServiceTest,StudentAfternoonRouteServiceTest,AdminDashboardServiceTest,BookingServiceTest test` from `backend/`: **passed**, 24 tests, 0 failures/errors. Maven compiled 67 production Java source files and the test classes needed for this selected suite.
- `git diff --check`: **passed**, no whitespace errors; Git emitted line-ending conversion warnings for existing modified files.
- `rg -n "Timer\.periodic|Timer\s*\(|ScheduledExecutor|scheduleAtFixedRate|scheduleWithFixedDelay|@Scheduled|WidgetsBindingObserver|didChangeAppLifecycleState|AppLifecycleState|retry\s*\(" frontend\lib backend\src\main\java`: no matches.
- `rg -l -i "(password|secret|access[_-]?token|api[_-]?key)\s*[:=]\s*['\"][^'\"]{8,}" frontend\lib frontend\test backend\src\main\java backend\src\test`: no matching source files. This was a pattern-based scan, not a credential audit.
- Android release-file path comparison returned no changed release configuration files.
- `git status --short`, `git diff --stat`, and the protected-path `git diff --name-only` checks were used to record the current worktree and detect pre-existing authentication/Android changes.
- `Get-Command dart`, `dart --version`, and `flutter --version`: Dart 3.11.5 and Flutter 3.41.9.
- `dart_format` was invoked for the edited assignment screen and Flutter test files. The installed CLI check (`dart format --output=none --set-exit-if-changed`) still reports a formatting difference in `afternoon_assignment_refresh_test.dart`; the broader check also flagged the pre-existing `admin_login_screen.dart`. The latter was left untouched to respect the authentication boundary. Flutter analysis and tests pass despite the formatter discrepancy.

An initial Maven test-compile attempt failed because the added unsupported-media test used the wrong Spring exception constructor; the test was corrected and the backend command above passed. An initial Flutter run failed because the route-error assertion expected one match while both the error banner and snackbar displayed the same message; the assertion was corrected. No remaining Flutter or backend test failures exist.

### Verification outcomes by evidence type

- **Verified automatically:** Flutter analysis and 22/22 frontend tests; compilation and 24/24 selected isolated backend tests; mocked request counts and response shapes; error statuses; seat capacity and faculty-seat rejection; tracked diff whitespace.
- **Verified through static inspection only:** no recurring refresh/synchronization mechanism; refresh call sites are initial one-time loads or explicit user actions; dashboard tab selection changes the view without invoking its refresh function; changed paths for authentication and Android release configuration.
- **Not verified:** live API response values, production/Neon data or writes, PostgreSQL execution of derived case-insensitive uniqueness queries, and the Spring application-context test.
- **Failed/unresolved check:** the installed Dart CLI formatter check still reports a layout difference for the assignment refresh test. The broader check also reports the existing login-screen file, which was not touched due to the protected auth scope. This is not a Flutter analysis or test failure.

### Automated coverage added or strengthened

- Route flow: successful create response, separate route ID/number/code values, GET by ID, update preserving an omitted code, valid code update, blank and duplicate code rejection, case-insensitive repository lookup, and verification that invalid updates neither mutate the entity nor save it. Added standalone Spring MVC POST/GET/not-found tests using mocked repositories.
- Allowed Routes: tests cover route-code payload serialization, restoring saved route-code selection, and missing route codes remaining unavailable rather than falling back to bus numbers.
- Assignment dates/refresh: tests verify the tomorrow-to-365-day discovery range, inclusive range boundaries, reversed-range rejection, surfaced API errors, preservation of the route search filter, and no extra requests after a second refresh tap while one is pending. The assignment controller test verifies assignments at both range endpoints.
- Dashboard: mocked HTTP tests verify one 90-day range request, detail loading only for the nearest scheduled date, no request increase when switching to Routes and back or after simulated elapsed time, and the intended range/detail requests after explicit refresh. Empty and failed responses are also covered.
- Route list: tests verify initial load does not repeat over simulated elapsed time, explicit refresh does issue a request, and failures render an error.
- Seat capacity: tests assert 55 physical seats, five faculty-only seats, 50 student-bookable seats, 50-seat student schedule capacity, and faculty-seat booking rejection before persistence. The seat service test checks the corresponding student-visible statuses.
- Errors: tests cover actionable validation 400, missing-resource 404, conflict 409, unsupported method 405, unsupported media type 415, generic unexpected 500 without internal message disclosure, and preserved login validation response shape.

### Automatic refresh and synchronization inspection

1. **Data refresh/synchronization:** the dashboard and assignment screens perform a single initial load in `initState`; subsequent reloads come from explicit refresh controls, pull-to-refresh, or an explicit date selection. Routes use a single initial list load and an explicit refresh action. Dashboard tab selection only changes the selected screen; it does not call `refresh()`. No recurring refresh, polling, automatic retry loop, or background synchronization was found.
2. **Unrelated timed behavior:** no scheduled/timer implementation was found. The `while` loop in `SeatLayout` parses a seat-row number; `BookingTimeRules` computes the booking-open window and does not schedule API requests.
3. **Test-only behavior:** widget tests advance simulated time by 30 minutes to assert request counts remain unchanged. This does not create a runtime timer.

Runtime request-count evidence: the dashboard widget test asserts one range request and one details request for the nearest scheduled date; switching to Routes and back plus simulated elapsed time leaves both counts unchanged. Its explicit refresh increments each expected count once, and a second tap while pending creates no additional request. Assignment tests likewise assert a single initial range request, no mutation requests during initial load/time advancement, one explicit range refresh, no duplicate request while pending, and preservation of the search filter.

### Isolation, scope, and limitations

- All 24 selected backend tests use controlled repository mocks or standalone MockMvc with mocked repositories. There is no H2/Testcontainers test profile in the project configuration, so no database-backed integration test was attempted.
- `BackendApplicationTests` (`@SpringBootTest`) was intentionally excluded because application startup may use the configured hosted Neon database. Therefore the **full backend suite was not run**. Production database reads/writes and live API behavior were not exercised.
- Route-code case-insensitive behavior was verified through the controller's `IgnoreCase` repository contract and mocked repository responses, not a real PostgreSQL collation/query.
- The assignment date-picker currently caps selectable dates at today + 365 days. Tests verify the active discovery boundary and service/controller range endpoints; no user-selectable range wider than that UI limit exists to exercise.
- No production database writes, migrations, or live Neon operations were performed.
- At the start of this verification, the worktree already contained diffs in `AdminAuthService.java`, `AuthService.java`, `AdminLoginRequest.java`, `LoginRequest.java`, `StudentController.java`, `TransportProfileController.java`, and `admin_login_screen.dart`. These authentication/identity-related diffs were not changed during this verification and were not reverted; their presence means the entire current worktree cannot be certified as authentication-untouched relative to `HEAD`. No Android release configuration files were modified.
- No commits or pushes were made. Unrelated existing changes, Android Gradle cache artifacts, and `frontend/lib.zip` were preserved.

## Scope notes and remaining limitations

- The shared exception handler retains the known login validation contract; authentication-related pre-existing worktree diffs are documented above and were left untouched during this verification.
- The Allowed Routes UI cannot display a real route code if the backend response omits it; it reports that condition rather than substituting a bus number.
- Production API/database state should be checked separately to confirm route-code values are populated and the deployed backend returns them.
