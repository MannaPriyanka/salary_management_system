import { apiRequest } from "./client";

export interface StatsRow {
  currency: string;
  headcount: number;
  total_base: string;
  average_base: string;
  median_base: string;
  min_base: string;
  max_base: string;
  as_of: string;
  group?: { id: number; name: string } | null;
}

export type Breakdown = "department" | "country" | "designation";

export function getSummary(): Promise<{ data: StatsRow[] }> {
  return apiRequest<{ data: StatsRow[] }>("/statistics/summary");
}

export function getBreakdown(by: Breakdown): Promise<{ data: StatsRow[] }> {
  return apiRequest<{ data: StatsRow[] }>(`/statistics/breakdown?by=${by}`);
}
