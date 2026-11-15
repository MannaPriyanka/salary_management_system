import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router";
import { afterEach, describe, expect, it, vi } from "vitest";
import { mockApi } from "../test/mockApi";
import { EmployeeDetailPage } from "./EmployeeDetailPage";

const employee = (overrides: Record<string, unknown> = {}) => ({
  id: 7,
  employee_code: "EMP00007",
  full_name: "Ravi Kumar",
  work_email: "ravi@example.test",
  department: { id: 1, name: "Finance" },
  designation: { id: 2, name: "Analyst" },
  country: { id: 3, name: "Germany", code: "DE" },
  employment_status: "active",
  joining_date: "2020-01-01",
  exit_date: null,
  archived: false,
  current_salary: "60000.00",
  current_currency: "EUR",
  ...overrides,
});

function renderDetail(routes: Parameters<typeof mockApi>[0]) {
  mockApi({
    "GET /employees/7": { body: { data: employee() } },
    "GET /employees/7/salary_revisions": {
      body: {
        data: [
          {
            id: 1,
            currency: "EUR",
            base_amount: "60000.00",
            effective_date: "2021-01-01",
            reason: "Initial",
            recorded_by: { id: 1, email: "hr@example.test" },
            recorded_at: "2021-01-01T10:00:00Z",
            components: [{ type: "bonus", amount: "1000.00", currency: "EUR" }],
          },
        ],
      },
    },
    "GET /employees/7/audit_entries": { body: { data: [] } },
    ...routes,
  });
  return render(
    <MemoryRouter initialEntries={["/employees/7"]}>
      <Routes>
        <Route path="/employees/:id" element={<EmployeeDetailPage />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("EmployeeDetailPage", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("shows the current salary and each revision with its currency and components", async () => {
    renderDetail({});

    expect(await screen.findByRole("heading", { name: "Ravi Kumar" })).toBeInTheDocument();
    expect(screen.getByText("EUR 60000.00")).toBeInTheDocument();
    expect(screen.getByText("2021-01-01")).toBeInTheDocument();
    expect(screen.getByText("bonus EUR 1000.00")).toBeInTheDocument();
  });

  it("offers archive only for exited employees", async () => {
    renderDetail({});
    await screen.findByRole("heading", { name: "Ravi Kumar" });
    expect(screen.queryByRole("button", { name: "Archive" })).not.toBeInTheDocument();
  });

  it("offers archive for an exited employee", async () => {
    vi.unstubAllGlobals();
    mockApi({
      "GET /employees/7": {
        body: { data: employee({ employment_status: "exited", exit_date: "2025-06-30" }) },
      },
      "GET /employees/7/salary_revisions": { body: { data: [] } },
      "GET /employees/7/audit_entries": { body: { data: [] } },
    });
    render(
      <MemoryRouter initialEntries={["/employees/7"]}>
        <Routes>
          <Route path="/employees/:id" element={<EmployeeDetailPage />} />
        </Routes>
      </MemoryRouter>,
    );

    expect(await screen.findByRole("button", { name: "Archive" })).toBeInTheDocument();
  });
});
