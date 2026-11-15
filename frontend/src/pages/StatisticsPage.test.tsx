import { render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { mockApi } from "../test/mockApi";
import { StatisticsPage } from "./StatisticsPage";

const summaryRow = {
  currency: "INR",
  headcount: 2,
  total_base: "1500000.00",
  average_base: "750000.00",
  median_base: "750000.00",
  min_base: "600000.00",
  max_base: "900000.00",
  as_of: "2026-11-15",
};

describe("StatisticsPage", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("shows each currency's figures separately, as the server returned them", async () => {
    mockApi({
      "GET /statistics/summary": {
        body: {
          data: [
            summaryRow,
            {
              ...summaryRow,
              currency: "USD",
              total_base: "90000.00",
              average_base: "45000.00",
              median_base: "45000.00",
              min_base: "40000.00",
              max_base: "50000.00",
              headcount: 2,
            },
          ],
        },
      },
      "GET /statistics/breakdown": {
        body: { data: [{ ...summaryRow, group: { id: 1, name: "Engineering" } }] },
      },
    });

    render(<StatisticsPage />);

    expect(await screen.findByLabelText("Summary in INR")).toHaveTextContent(
      "Total base: 1500000.00",
    );
    expect(screen.getByLabelText("Summary in USD")).toHaveTextContent("Total base: 90000.00");
    expect(screen.getByRole("cell", { name: "Engineering" })).toBeInTheDocument();
  });

  it("says so when no salary is in force", async () => {
    mockApi({
      "GET /statistics/summary": { body: { data: [] } },
      "GET /statistics/breakdown": { body: { data: [] } },
    });

    render(<StatisticsPage />);

    expect(
      await screen.findByText(/no employees have a salary in force today/i),
    ).toBeInTheDocument();
  });
});
