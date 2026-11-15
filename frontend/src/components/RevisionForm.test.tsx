import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { mockApi } from "../test/mockApi";
import { RevisionForm } from "./RevisionForm";

const currencies = {
  data: [
    { code: "INR", name: "Indian Rupee", minor_units: 2 },
    { code: "USD", name: "US Dollar", minor_units: 2 },
  ],
};

describe("RevisionForm", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("sends the amounts as strings with the components", async () => {
    const { calls } = mockApi({
      "GET /currencies": { body: currencies },
      "POST /employees/7/salary_revisions": {
        status: 201,
        body: {
          data: {
            id: 1,
            currency: "INR",
            base_amount: "125000.50",
            effective_date: "2026-04-01",
            reason: "Review",
            recorded_by: { id: 1, email: "hr@example.test" },
            recorded_at: "2026-11-15T10:00:00Z",
            components: [],
          },
        },
      },
    });
    const onSaved = vi.fn();

    render(<RevisionForm employeeId={7} onSaved={onSaved} onCancel={() => {}} />);
    await screen.findByText("INR");
    fireEvent.change(screen.getByLabelText(/base amount/i), { target: { value: "125000.50" } });
    fireEvent.change(screen.getByLabelText(/effective date/i), { target: { value: "2026-04-01" } });
    fireEvent.change(screen.getByLabelText(/allowance/i), { target: { value: "5000.00" } });
    fireEvent.click(screen.getByRole("button", { name: /save revision/i }));

    await waitFor(() => expect(onSaved).toHaveBeenCalled());
    const body = calls.find((call) => call.method === "POST")?.body as Record<string, unknown>;
    expect(body).toMatchObject({
      currency: "INR",
      base_amount: "125000.50",
      effective_date: "2026-04-01",
      components: [{ type: "allowance", amount: "5000.00", currency: "INR" }],
    });
  });

  it("shows the server's message under the field it belongs to", async () => {
    mockApi({
      "GET /currencies": { body: currencies },
      "POST /employees/7/salary_revisions": {
        status: 422,
        body: {
          error: {
            code: "validation_failed",
            message: "One or more fields are invalid.",
            details: [{ field: "base_amount", message: "must have at most 2 decimal places" }],
          },
        },
      },
    });

    render(<RevisionForm employeeId={7} onSaved={() => {}} onCancel={() => {}} />);
    await screen.findByText("INR");
    fireEvent.change(screen.getByLabelText(/base amount/i), { target: { value: "1000.005" } });
    fireEvent.change(screen.getByLabelText(/effective date/i), { target: { value: "2026-04-01" } });
    fireEvent.click(screen.getByRole("button", { name: /save revision/i }));

    expect(await screen.findByText("must have at most 2 decimal places")).toBeInTheDocument();
  });

  it("explains a duplicate effective date", async () => {
    mockApi({
      "GET /currencies": { body: currencies },
      "POST /employees/7/salary_revisions": {
        status: 409,
        body: {
          error: {
            code: "effective_date_conflict",
            message: "A salary revision already exists for this effective date.",
            details: [],
          },
        },
      },
    });

    render(<RevisionForm employeeId={7} onSaved={() => {}} onCancel={() => {}} />);
    await screen.findByText("INR");
    fireEvent.change(screen.getByLabelText(/base amount/i), { target: { value: "100.00" } });
    fireEvent.change(screen.getByLabelText(/effective date/i), { target: { value: "2026-04-01" } });
    fireEvent.click(screen.getByRole("button", { name: /save revision/i }));

    expect(await screen.findByText(/already exists for this effective date/i)).toBeInTheDocument();
  });
});
