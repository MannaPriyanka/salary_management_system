import { apiRequest } from "./client";

export interface Named {
  id: number;
  name: string;
}

export interface EmployeeSummary {
  id: number;
  employee_code: string;
  full_name: string;
  work_email: string;
  department: Named;
  designation: Named;
  country: Named & { code: string };
  employment_status: "active" | "on_leave" | "exited";
  joining_date: string;
  exit_date: string | null;
  archived: boolean;
  current_salary: string | null;
  current_currency: string | null;
}

export interface Page<T> {
  data: T[];
  meta: { page: number; per_page: number; total_count?: number; total_pages?: number };
}

export interface EmployeeInput {
  employee_code?: string;
  full_name: string;
  work_email: string;
  department_id: number | "";
  designation_id: number | "";
  country_id: number | "";
  employment_status: "active" | "on_leave" | "exited";
  joining_date: string;
  exit_date?: string | null;
}

export interface Component {
  type: "allowance" | "bonus";
  amount: string;
  currency: string;
}

export interface Revision {
  id: number;
  currency: string;
  base_amount: string;
  effective_date: string;
  reason: string | null;
  recorded_by: { id: number; email: string };
  recorded_at: string;
  components: Component[];
}

export interface RevisionInput {
  currency: string;
  base_amount: string;
  effective_date: string;
  reason: string;
  components: Component[];
}

export interface AuditEntry {
  occurred_at: string;
  actor: { id: number; email: string } | null;
  action: string;
  entity_type: string;
  entity_id: string;
  previous_values: Record<string, unknown> | null;
  new_values: Record<string, unknown> | null;
}

export type Employee = EmployeeSummary;

export interface EmployeeFilters {
  q?: string;
  department_id?: string;
  employment_status?: string;
  include_archived?: boolean;
  page?: number;
}

export function listEmployees(filters: EmployeeFilters): Promise<Page<EmployeeSummary>> {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== "" && value !== false) params.set(key, String(value));
  });
  return apiRequest<Page<EmployeeSummary>>(`/employees?${params.toString()}`);
}

export function getEmployee(id: number): Promise<{ data: Employee }> {
  return apiRequest<{ data: Employee }>(`/employees/${id}`);
}

export function createEmployee(input: EmployeeInput): Promise<{ data: Employee }> {
  return apiRequest<{ data: Employee }>("/employees", { method: "POST", body: input });
}

export function updateEmployee(
  id: number,
  input: Partial<EmployeeInput>,
): Promise<{ data: Employee }> {
  return apiRequest<{ data: Employee }>(`/employees/${id}`, { method: "PATCH", body: input });
}

export function archiveEmployee(id: number): Promise<{ data: Employee }> {
  return apiRequest<{ data: Employee }>(`/employees/${id}/archive`, { method: "POST" });
}

export function unarchiveEmployee(id: number): Promise<{ data: Employee }> {
  return apiRequest<{ data: Employee }>(`/employees/${id}/unarchive`, { method: "POST" });
}

export function listRevisions(employeeId: number): Promise<{ data: Revision[] }> {
  return apiRequest<{ data: Revision[] }>(
    `/employees/${employeeId}/salary_revisions?order=effective_asc`,
  );
}

export function createRevision(
  employeeId: number,
  input: RevisionInput,
): Promise<{ data: Revision }> {
  return apiRequest<{ data: Revision }>(`/employees/${employeeId}/salary_revisions`, {
    method: "POST",
    body: input,
  });
}

export function listAuditEntries(employeeId: number): Promise<{ data: AuditEntry[] }> {
  return apiRequest<{ data: AuditEntry[] }>(`/employees/${employeeId}/audit_entries`);
}

export function listNamed(
  resource: "departments" | "designations" | "countries",
): Promise<{ data: Array<Named & { code?: string }> }> {
  return apiRequest(`/${resource}`);
}

export function listCurrencies(): Promise<{
  data: Array<{ code: string; name: string; minor_units: number }>;
}> {
  return apiRequest("/currencies");
}
