import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router";
import { afterEach, describe, expect, it, vi } from "vitest";
import { mockApi } from "../test/mockApi";
import { EmployeesPage } from "./EmployeesPage";

const employeeRow = {
  id: 1,
  employee_code: "EMP00001",
  full_name: "Asha Rao",
  work_email: "asha@example.test",
  department: { id: 1, name: "Engineering" },
  designation: { id: 1, name: "Engineer" },
  country: { id: 1, name: "India", code: "IN" },
  employment_status: "active",
  joining_date: "2020-01-15",
  exit_date: null,
  archived: false,
  current_salary: "125000.50",
  current_currency: "INR",
};

function renderPage() {
  return render(
    <MemoryRouter>
      <EmployeesPage />
    </MemoryRouter>,
  );
}

describe("EmployeesPage", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("shows employees with their current salary as the server returned it", async () => {
    mockApi({
      "GET /departments": { body: { data: [{ id: 1, name: "Engineering" }] } },
      "GET /employees": {
        body: {
          data: [employeeRow],
          meta: { page: 1, per_page: 25, total_count: 1, total_pages: 1 },
        },
      },
    });

    renderPage();

    expect(await screen.findByText("Asha Rao")).toBeInTheDocument();
    expect(screen.getByText("INR 125000.50")).toBeInTheDocument();
  });

  it("asks the server for matching employees when the search text changes", async () => {
    const { calls } = mockApi({
      "GET /departments": { body: { data: [] } },
      "GET /employees": { body: { data: [], meta: { page: 1, per_page: 25, total_pages: 1 } } },
    });

    renderPage();
    await screen.findByText(/no employees match/i);
    fireEvent.change(screen.getByLabelText(/search by name or code/i), {
      target: { value: "ravi" },
    });

    await waitFor(() => {
      const last = calls.filter((call) => call.url.pathname === "/api/v1/employees").at(-1);
      expect(last?.url.searchParams.get("q")).toBe("ravi");
    });
  });
});
