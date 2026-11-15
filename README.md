# Employee Salary Management System

## Introduction

This project is a web-based salary management system for ACME's HR team. Today, salary data for roughly 10,000 employees across multiple countries is maintained in Excel spreadsheets, which is slow, error-prone, and hard to analyse. The goal is to give the HR Manager a single place to manage salary records and to answer questions about how the organisation pays its people.

## Contents

- [Features](#features)
- [Architecture](#architecture)
- [Data model](#data-model)
- [API reference](#api-reference)
- [Web app screens](#web-app-screens)
- [Project layout](#project-layout)
- [Setup](#setup)
- [Configuration](#configuration)
- [Tests and quality checks](#tests-and-quality-checks)
- [Continuous integration](#continuous-integration)
- [Deployment](#deployment)
- [Security](#security)
- [Business rules](#business-rules)

## Features

| Area | What the HR Manager can do |
|---|---|
| Sign-in | Sign in with the seeded HR Manager account, sign out, and change the password. Repeated wrong passwords are refused for 15 minutes (see [Security](#security)). |
| Employees | Add, edit, search by name or code, filter by department, country, designation, and status, and page through the list. |
| Archive | Archive an **exited** employee, or restore one. Archiving never deletes salary history. Archived employees are hidden by default. |
| Salary revisions | Record a base salary with an effective date, optional allowance and bonus components, and a reason. Revisions are append-only: corrections are new revisions. |
| Salary history | See every revision in effective-date order, with its currency and who recorded it. Visible for archived employees too. |
| Current salary | The latest revision in force today is shown on each employee and in the list. |
| Pay statistics | Headcount, total, average, median, minimum, and maximum base salary per currency. Breakdown by department, country, or designation. |
| Audit trail | Every employee and salary change records the actor, the action, previous and new values, and the time. |
| Currencies | INR, USD, EUR, and GBP. Every amount keeps its own currency. Totals are never added across currencies. |
| Seed data | A deterministic command creates 10,000 synthetic employees and salary histories. Repeat runs change nothing. |

Not included in this version (see [roadmap](#known-limitations-and-roadmap)): CSV import and export, a read-only Viewer role, monthly run rate and trend reports, cohort comparisons, currency conversion, payroll, employee self-service, approval workflow, account management screens, and multi-factor sign-in.

## Architecture

One deployable application, one database, one browser client.

```
Browser (React SPA)  --HTTPS, session cookie-->  Rails 8.1 application
                                                 ├── JSON API under /api/v1
                                                 ├── Serves the built SPA (public/)
                                                 └── PostgreSQL 17
```

- **Backend:** Ruby on Rails 8.1 in API mode. Modular monolith: separated by namespace and directory, deployed as one unit. No background workers, no Redis, no message queue (none is needed for the MVP).
- **Frontend:** React 19 with TypeScript, built by Vite, using MUI components and React Router. The built files are served by Rails from `public/`, so the browser sees one origin and session cookies need no cross-site setup. In development, Vite proxies `/api` to Rails.
- **Database:** PostgreSQL only. Exact decimal money (`NUMERIC(18,4)`), database constraints for business rules, and row locks for concurrent revisions.

Backend modules:

| Module | Location | Responsibility |
|---|---|---|
| Sessions | `app/controllers/api/v1/sessions_controller.rb`, `app/models/sign_in_protection.rb` | Sign-in, sign-out, password change, sign-in protection |
| Employees | `app/models/employee.rb`, `app/controllers/api/v1/employees_controller.rb`, `app/queries/employee_search.rb` | Employee records, search, archive |
| Compensation | `app/models/salary_revision.rb`, `revision_component.rb`, `app/controllers/api/v1/salary_revisions_controller.rb` | Revisions, components, history |
| Statistics | `app/queries/pay_statistics.rb`, `app/controllers/api/v1/statistics_controller.rb` | Current pay figures per currency |
| Audit | `app/models/audit_recorder.rb`, `audit_log.rb`, `current.rb` | Change history written by model callbacks |
| Money | `app/models/money.rb` | Decimal precision checks and string formatting |
| Seed and bootstrap | `app/services/synthetic_seed.rb`, `app/services/bootstrap/hr_manager.rb`, `app/services/development_credentials.rb` | Synthetic data, the initial HR Manager account, and the development-password guard |

Design decisions are recorded in [`docs/architecture/architecture-decisions/`](docs/architecture/architecture-decisions/README.md) (ADR-0001 to ADR-0009). Deviations from the original design are listed in [Known limitations](#known-limitations-and-roadmap).

### Request lifecycle: recording a salary revision

1. The browser sends `POST /api/v1/employees/:id/salary_revisions` with the session cookie.
2. The controller requires a signed-in user and reads the parameters. Amounts must be JSON strings; JSON numbers are rejected.
3. Inside one transaction, the employee row is locked. This serialises concurrent revisions and joining-date changes.
4. The model checks: positive amounts, enabled currency, decimal places within the currency's limit, effective date not before joining date or after exit date, and no other revision on the same date.
5. The revision and its components are saved, and the audit entry is written in the same transaction.
6. The response returns amounts as strings. Validation errors return 422 with field details. A duplicate effective date returns 409.

## Data model

| Table | Purpose | Key rules |
|---|---|---|
| `currencies` | ISO codes, names, decimal places, enabled flag | Code is three uppercase letters; decimal places 0–4 |
| `countries`, `departments`, `designations` | Reference lists | Names unique (case-insensitive) |
| `users` | The HR Manager account | Unique email, bcrypt password digest |
| `employees` | Employee records | Unique code and work email; exit date after joining date; exit date required for `exited`; archive only when `exited` |
| `salary_revisions` | Base salary history | Unique (employee, effective date); base > 0; append-only |
| `revision_components` | Allowance and bonus on a revision | Type `allowance` or `bonus`, at most one of each per revision; same currency as its revision |
| `audit_logs` | Change history | Append-only; actor, action, entity, previous and new values |

Migrations are in `db/migrate/`. The current schema is in `db/schema.rb`. An entity-relationship diagram is in [`docs/architecture/database-design.md`](docs/architecture/database-design.md).

## API reference

All endpoints are under `/api/v1` and return JSON. Every endpoint requires a signed-in HR Manager (session cookie), except `POST /api/v1/session` (sign-in) and `GET /api/v1/health`.

**Conventions**

- **Money:** amounts are JSON strings with the currency's decimal places, for example `"125000.50"`. Requests must send strings too.
- **Dates:** `YYYY-MM-DD`. Timestamps are ISO 8601 in UTC.
- **Pagination:** `page` (from 1) and `per_page` (default 25, maximum 100). Responses include `meta` with `page`, `per_page`, `total_count`, and `total_pages`.
- **Errors:** every error has the same shape:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "One or more fields are invalid.",
    "details": [{ "field": "effective_date", "message": "cannot be before the joining date (2020-01-01)" }]
  }
}
```

Common codes: `not_signed_in` (401), `invalid_credentials` (401), `sign_in_refused` (429, with `Retry-After`), `validation_failed` (422), `not_exited` (422), `duplicate_identifier` (409), `effective_date_conflict` (409), `invalid_breakdown` (422), `not_found` (404).

### Session

| Method | Path | Body | Result |
|---|---|---|---|
| POST | `/api/v1/session` | `{ "email", "password" }` | 201 with the user, sets the session cookie. 401 `invalid_credentials` for a wrong password or unknown email (same response). 429 `sign_in_refused` while refused. |
| GET | `/api/v1/session` | — | 200 with the current user, or 401 |
| DELETE | `/api/v1/session` | — | 204, ends the session |
| PUT | `/api/v1/session/password` | `{ "current_password", "new_password" }` | 204. 422 if the current password is wrong or the new one is shorter than 12 characters. |

### Employees

| Method | Path | Notes |
|---|---|---|
| GET | `/api/v1/employees` | Query: `q` (name or code, case-insensitive), `department_id`, `designation_id`, `country_id`, `employment_status`, `include_archived` (`true` to include archived), `page`, `per_page`. Sorted by employee code. |
| POST | `/api/v1/employees` | Fields: `employee_code`, `full_name`, `work_email`, `department_id`, `designation_id`, `country_id`, `employment_status` (`active`, `on_leave`, `exited`), `joining_date`, `exit_date`. 409 names the existing record if the code or email is taken. |
| GET | `/api/v1/employees/:id` | Employee with `current_salary` and `current_currency` |
| PATCH | `/api/v1/employees/:id` | Editable fields. The employee code cannot change. A joining date that conflicts with a revision returns 422 and lists the revisions. |
| POST | `/api/v1/employees/:id/archive` | Only for `exited` employees (422 `not_exited` otherwise) |
| POST | `/api/v1/employees/:id/unarchive` | Restores an archived employee |

Employee rows include `id`, `employee_code`, `full_name`, `work_email`, `department`, `designation`, `country`, `employment_status`, `joining_date`, `exit_date`, `archived`, `current_salary`, and `current_currency`. The list fetches current salaries in one query, so its cost does not grow with the page size.

### Salary revisions and audit

| Method | Path | Notes |
|---|---|---|
| GET | `/api/v1/employees/:employee_id/salary_revisions` | History. `order=effective_asc` (default) or `effective_desc`. |
| POST | `/api/v1/employees/:employee_id/salary_revisions` | Body: `currency`, `base_amount` (string), `effective_date`, `reason`, `components` (array of `{ "type": "allowance" or "bonus", "amount": "<string>", "currency" }`). Returns 201 with the revision. |
| GET | `/api/v1/employees/:employee_id/audit_entries` | Change history for the employee and its revisions, newest first, 50 per page |

There is intentionally **no** endpoint to edit or delete a revision (it returns 404). A correction is a new revision.

### Reference data (read only)

| Method | Path | Returns |
|---|---|---|
| GET | `/api/v1/departments` | Active departments (`id`, `name`) |
| GET | `/api/v1/designations` | Active designations (`id`, `name`) |
| GET | `/api/v1/countries` | Active countries (`id`, `name`, `code`) |
| GET | `/api/v1/currencies` | Enabled currencies (`code`, `name`, `minor_units`) |

### Pay statistics

| Method | Path | Notes |
|---|---|---|
| GET | `/api/v1/statistics/summary` | One row per currency. Optional filters: `department_id`, `country_id`, `designation_id`. |
| GET | `/api/v1/statistics/breakdown?by=department` | `by` is `department`, `country`, or `designation`. One row per group per currency. Any other value returns 422 `invalid_breakdown`. |

Each row has `currency`, `headcount`, `total_base`, `average_base`, `median_base`, `min_base`, `max_base`, `as_of`, and `group` (for breakdowns). Figures are for employees who are not archived, are employed on the date, and have a salary in force. Averages and medians are rounded half-up to the currency's decimal places for display. An empty population returns an empty list, not zeros.

### Health

`GET /api/v1/health` returns `{ "status": "ok" }` when the application can reach the database. It exposes no version or environment details.

## Web app screens

| Route | Screen |
|---|---|
| `/sign-in` | Sign-in form. Wrong credentials and unknown emails show the same message. |
| `/employees` | Employee list with search, department and status filters, archived toggle, and paging |
| `/employees/new` | Add an employee |
| `/employees/:id` | Employee details, current salary, salary history, record a revision, change history, archive or restore |
| `/employees/:id/edit` | Edit an employee (the code is read only) |
| `/statistics` | Pay statistics per currency, with a breakdown by department, country, or designation |

Unknown client-side routes load the app, which shows the right screen on refresh. Unknown `/api/...` paths return a JSON 404.

## Project layout

```
.
├── app/
│   ├── controllers/      Api::V1 controllers, SPA and error endpoints
│   ├── models/           Employee, SalaryRevision, RevisionComponent, Currency, User, AuditLog, Money, ...
│   ├── queries/          EmployeeSearch, CurrentSalaries, PayStatistics
│   └── services/         SyntheticSeed, Bootstrap::HrManager, DevelopmentCredentials
├── config/               Rails configuration, routes, database.yml
├── db/migrate/           Migrations (schema in db/schema.rb)
├── lib/tasks/            seed:synthetic and accounts:bootstrap_hr_manager
├── spec/                 RSpec: models, queries, services, requests
├── frontend/             React app (src/api, src/pages, src/components, src/auth)
├── public/               Built web app is written here by `npm run build`
├── docs/                 Requirements, architecture, decisions, roadmap
├── Dockerfile            Multi-stage: React build, then the Rails image
├── docker-compose.yml    Local PostgreSQL
└── .github/workflows/ci.yml
```

## Setup

### Prerequisites

- Ruby 3.4.5 (see `.ruby-version`) and Bundler 2.7.2
- Node.js 24 and npm
- PostgreSQL 17, either running locally on port 5432 or through Docker Compose

### 1. Clone and install

```sh
git clone <repository-url> salary_management_system
cd salary_management_system
bundle install
(cd frontend && npm ci)
```

### 2. Start PostgreSQL

With Docker:

```sh
docker compose up -d db          # PostgreSQL 17 on localhost:5432, user postgres / password postgres
```

Or use a local PostgreSQL server listening on port 5432 with a role that can create databases. The development and test databases are `salary_app_development` and `salary_app_test`.

> The Docker Compose file has been checked for syntax but not started on this machine. The Docker daemon was not running during development.

### 3. Create the databases and run migrations

```sh
bin/rails db:prepare
```

### 4. Create the HR Manager account

```sh
bin/rails accounts:bootstrap_hr_manager
```

In development, this creates `hr.manager@example.test` with the built-in development password. In production, it requires `HR_MANAGER_EMAIL` and `HR_MANAGER_PASSWORD` (see [Configuration](#configuration)).

### 5. Load synthetic data (optional, recommended for a demo)

```sh
bin/rails seed:synthetic                 # 10,000 employees, about 3 seconds
EMPLOYEE_COUNT=500 bin/rails seed:synthetic   # a smaller set
```

Requires step 4 first, because the seeded revisions are recorded by the HR Manager account. Running it again changes nothing. Seeding is never run automatically.

### 6. Build the web app and start the server

```sh
(cd frontend && npm run build)           # writes public/index.html and public/assets/
bin/rails server                         # http://localhost:3000
```

Open http://localhost:3000 and sign in.

### Developing the web app with hot reload

```sh
bin/rails server                         # API on :3000
(cd frontend && npm run dev)             # web app on http://localhost:5173, /api proxied to :3000
```

### Useful commands

| Command | Purpose |
|---|---|
| `bin/rails db:prepare` | Create and migrate the databases |
| `bin/rails db:rollback STEP=1` | Undo the last migration (development only) |
| `bin/rails accounts:bootstrap_hr_manager` | Create the initial HR Manager account |
| `bin/rails seed:synthetic` | Create synthetic employees and salary histories |
| `bin/rails routes -g api` | List the API routes |

## Configuration

| Variable | Used by | Required | Purpose |
|---|---|---|---|
| `DATABASE_HOST` | `config/database.yml` (all environments) | No (unset = Unix socket) | Database host, for example `localhost` |
| `DATABASE_PORT` | `config/database.yml` | No (default 5432) | Database port |
| `DATABASE_USERNAME` | `config/database.yml` | No (unset = operating system user) | Development and test database user |
| `DATABASE_PASSWORD` | `config/database.yml` | No (unset = no password) | Development and test database password |
| `DATABASE_URL` | Rails (production) | Yes in production, unless the variables below are set | Full PostgreSQL connection URL. Merged over `config/database.yml`. |
| `SALARY_APP_DATABASE_USER` | `config/database.yml` | No (default `salary_app`) | Production database user |
| `SALARY_APP_DATABASE_PASSWORD` | `config/database.yml` | Yes in production when `DATABASE_URL` is not set | Production database password |
| `SECRET_KEY_BASE` or `RAILS_MASTER_KEY` | Rails (production) | Yes in production | Signs and encrypts session cookies |
| `HR_MANAGER_EMAIL` | `accounts:bootstrap_hr_manager` | Yes in production | Email of the initial HR Manager |
| `HR_MANAGER_PASSWORD` | `accounts:bootstrap_hr_manager` | Yes in production | Password of the initial HR Manager (at least 12 characters, not the development password) |
| `EMPLOYEE_COUNT` | `seed:synthetic` | No (default 10,000) | Number of synthetic employees |
| `RAILS_LOG_LEVEL` | Rails | No (default `info`) | Log level |
| `RAILS_MAX_THREADS` | Rails | No (default 5) | Threads per process, also the database pool size |
| `WEB_CONCURRENCY` | Puma | No | Number of worker processes |
| `PORT` | Puma | No (default 3000) | HTTP port |

Secrets belong in the environment or the platform's secret store. Never commit them. `config/master.key` and `*.key` files are git-ignored.

## Tests and quality checks

```sh
bundle exec rspec                        # backend: 156 examples (models, queries, services, requests)
bundle exec rubocop                      # style
bundle exec brakeman -q --no-pager       # static security analysis
bundle exec bundler-audit check          # known gem vulnerabilities

cd frontend
npm test                                 # 19 tests (React Testing Library, mocked API)
npm run typecheck
npm run lint
npm run format:check
```

What the tests cover:

- **Model rules:** validations, database constraints, append-only revisions, joining and exit date rules, decimal precision.
- **Requests:** every endpoint, status codes, error shapes, authorization (401 without a session), pagination, and the query count for the list (no N+1).
- **Sign-in protection:** threshold, refusal window, recovery, identical responses for known and unknown emails, and reset after success. All with a controlled clock.
- **Statistics:** exact values, half-up rounding, medians, currency separation, and which employees are included.
- **Seed and bootstrap:** counts, repeatability, date validity, development-password refusal in production, and the startup guard.
- **Frontend:** API client error handling, sign-in messages, route protection, the list, revision form (amounts sent as strings, server errors shown under the right field), and the detail page.

Test conventions: no sleeps, a controlled clock for time-based rules, the cache cleared before each example, and the four MVP currencies created before each example.

## Continuous integration

`.github/workflows/ci.yml` runs on every push to `main` and every pull request:

| Job | Steps |
|---|---|
| `scan_ruby` | Brakeman, bundler-audit |
| `test` | PostgreSQL 17 service, `db:prepare`, RSpec |
| `frontend` | `npm ci`, typecheck, lint, format check, tests, build |
| `lint` | RuboCop |

The CI workflow has been checked for valid YAML and its frontend steps have been run locally. It has not yet run on GitHub.

## Deployment

The `Dockerfile` has three stages: a Node stage that builds the React app, a build stage that installs gems, and the final Rails image that runs as a non-root user.

```sh
docker build -t salary_app .             # not yet verified on this machine
docker run -d -p 3000:3000 \
  -e DATABASE_URL="postgres://USER:PASSWORD@HOST:5432/salary_app_production" \
  -e SECRET_KEY_BASE="<long random value>" \
  salary_app
```

- The entrypoint runs `db:prepare` before the server starts. It creates no data, because the seed is not part of `db:prepare`.
- Create the HR Manager once, for example with `docker run --rm -e ... salary_app ./bin/rails accounts:bootstrap_hr_manager`.
- Production refuses to start while any account uses the development password.
- Production sets `force_ssl`. Put the container behind a TLS-terminating proxy or platform load balancer.
- The application serves the React app and the API from one process, so no separate frontend host is needed.

The hosting platform is not yet chosen (see [ADR-0008](docs/architecture/architecture-decisions/ADR-0008-hosting-platform.md)). Image build and deployment have not been verified.

## Security

- **Authentication:** session cookie (HTTP-only, SameSite Lax, secure in production). The session is reset on sign-in and sign-out. Passwords are stored as bcrypt digests and must be at least 12 characters.
- **Sign-in protection (provisional values):** after 5 failed attempts for an email within 15 minutes, sign-in for that email is refused for 15 minutes. The count is kept by normalised email, so unknown emails are treated the same way and the responses do not reveal which accounts exist. A successful sign-in clears the count. There is no permanent lockout. Rails' `rate_limit` also limits sign-in attempts per IP (30 per 15 minutes).
- **Authorization:** every data endpoint requires a session. There is one role, so there is no per-record authorization yet.
- **Money handling:** no floating-point numbers anywhere in the money path. Amounts are strings in and out.
- **Audit trail:** every employee and salary change is recorded in the same transaction as the change.
- **Development credentials:** the development password is refused by the production bootstrap, and the server refuses to start in production if any account still uses it.
- **Data exposure:** salary values are not written to application logs.
- **Synthetic data only:** the seed uses fictitious names and `example.test` addresses.

Full design: [`docs/architecture/security-design.md`](docs/architecture/security-design.md).

## Business rules

- One salary revision per employee per effective date.
- A revision cannot take effect before the employee's joining date, or after the exit date for an exited employee.
- Changing a joining date is rejected if an existing revision would fall before the new date. Revisions are never moved automatically.
- Amounts must be greater than zero and must not exceed the currency's decimal places. Extra decimals are rejected, never rounded.
- A component uses the same currency as its revision.
- Only an `exited` employee can be archived. Archiving does not change any revision, component, or audit entry.
- The current salary is the latest revision effective on or before today.
- Statistics are per currency. An employee counts only if they are not archived, are employed on the date, and have a salary in force.
- Employee codes and work emails are unique. A returning person is not detected if they use a new code and a new email.

## Known limitations and roadmap

**Limitations in this version**
- One HR Manager account. No password reset by email, no account management screen.
- Sign-in protection values are provisional defaults, and they can delay a real user during an attack.
- Sign-in protection counters and rate limits use Rails' cache. Production uses the default file cache on the same host. Multiple hosts need a shared cache store.
- No duplicate detection for a returning employee who uses a new code and a new email. Re-hire is not supported.
- Revisions cannot be edited or deleted. A mistake is corrected by a new revision, which is intended but means the history keeps the mistake.
- Pay statistics are computed live on each request. This is fine for 10,000 employees, but has not been measured against the performance targets yet.
- The Docker image build, the GitHub CI run, and deployment are not yet verified.

**Deviations from the original design documents**
- Sessions use Rails' cookie session rather than the generator's sessions table. Sign-in protection state lives in the cache instead of on the user record.
- The median is computed in Ruby with exact decimals. PostgreSQL's `percentile_cont` returns a floating-point number.
- The environment check uses Rails' `RAILS_ENV` rather than a separate `APP_ENV` variable.

**Roadmap** (documented, not built; see [`docs/product/roadmap.md`](docs/product/roadmap.md))
- Read-only Viewer role with privacy suppression, and an audit of Viewer requests
- CSV import and export, with background processing and retries
- Monthly run rate, trend reports, and comparison cohorts
- Advanced sign-in protection, multi-factor sign-in
- Re-hire support through an employment-period model
- Currency conversion, additional currencies
- Retention policies, once the applicable country laws are confirmed. **No legal or regulatory compliance is claimed.**
- Payroll integration, employee self-service, approval workflow, multi-tenancy
