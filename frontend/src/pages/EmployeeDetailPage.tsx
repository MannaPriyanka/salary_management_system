import { useCallback, useEffect, useState } from "react";
import { Link as RouterLink, useParams } from "react-router";
import Alert from "@mui/material/Alert";
import Button from "@mui/material/Button";
import Divider from "@mui/material/Divider";
import Paper from "@mui/material/Paper";
import Stack from "@mui/material/Stack";
import Table from "@mui/material/Table";
import TableBody from "@mui/material/TableBody";
import TableCell from "@mui/material/TableCell";
import TableHead from "@mui/material/TableHead";
import TableRow from "@mui/material/TableRow";
import Typography from "@mui/material/Typography";
import {
  archiveEmployee,
  getEmployee,
  listAuditEntries,
  listRevisions,
  unarchiveEmployee,
  type AuditEntry,
  type Employee,
  type Revision,
} from "../api/employees";
import { errorMessage } from "../api/errors";
import { RevisionForm } from "../components/RevisionForm";

export function EmployeeDetailPage() {
  const { id } = useParams();
  const employeeId = Number(id);
  const [employee, setEmployee] = useState<Employee | null>(null);
  const [revisions, setRevisions] = useState<Revision[]>([]);
  const [audit, setAudit] = useState<AuditEntry[]>([]);
  const [adding, setAdding] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchDetail = useCallback(
    () =>
      Promise.all([
        getEmployee(employeeId),
        listRevisions(employeeId),
        listAuditEntries(employeeId),
      ]).then(([employeeBody, revisionBody, auditBody]) => ({
        employee: employeeBody.data,
        revisions: revisionBody.data,
        audit: auditBody.data,
      })),
    [employeeId],
  );

  const applyDetail = useCallback((detail: Awaited<ReturnType<typeof fetchDetail>>) => {
    setEmployee(detail.employee);
    setRevisions(detail.revisions);
    setAudit(detail.audit);
  }, []);

  const reload = useCallback(
    () =>
      fetchDetail()
        .then(applyDetail)
        .catch((caught: unknown) => setError(errorMessage(caught))),
    [fetchDetail, applyDetail],
  );

  useEffect(() => {
    let cancelled = false;
    fetchDetail()
      .then((detail) => {
        if (!cancelled) applyDetail(detail);
      })
      .catch((caught: unknown) => {
        if (!cancelled) setError(errorMessage(caught));
      });
    return () => {
      cancelled = true;
    };
  }, [fetchDetail, applyDetail]);

  async function toggleArchive() {
    if (!employee) return;
    try {
      if (employee.archived) {
        await unarchiveEmployee(employee.id);
      } else {
        await archiveEmployee(employee.id);
      }
      await reload();
    } catch (caught) {
      setError(errorMessage(caught));
    }
  }

  if (!employee) {
    return error ? <Alert severity="error">{error}</Alert> : <Typography>Loading…</Typography>;
  }

  return (
    <Stack spacing={3}>
      <Stack
        direction="row"
        sx={{ justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: 2 }}
      >
        <Typography variant="h5" component="h2">
          {employee.full_name}
          {employee.archived && " (archived)"}
        </Typography>
        <Stack direction="row" spacing={1}>
          <Button component={RouterLink} to={`/employees/${employee.id}/edit`}>
            Edit
          </Button>
          {(employee.employment_status === "exited" || employee.archived) && (
            <Button onClick={toggleArchive}>{employee.archived ? "Restore" : "Archive"}</Button>
          )}
        </Stack>
      </Stack>

      {error && <Alert severity="error">{error}</Alert>}

      <Paper sx={{ p: 3 }}>
        <Stack direction={{ xs: "column", sm: "row" }} spacing={4}>
          <Field label="Employee code" value={employee.employee_code} />
          <Field label="Work email" value={employee.work_email} />
          <Field label="Department" value={employee.department.name} />
          <Field label="Designation" value={employee.designation.name} />
          <Field label="Country" value={employee.country.name} />
        </Stack>
        <Divider sx={{ my: 2 }} />
        <Stack direction={{ xs: "column", sm: "row" }} spacing={4}>
          <Field label="Status" value={employee.employment_status} />
          <Field label="Joining date" value={employee.joining_date} />
          <Field label="Exit date" value={employee.exit_date ?? "—"} />
          <Field
            label="Current salary"
            value={
              employee.current_salary
                ? `${employee.current_currency} ${employee.current_salary}`
                : "No salary in force"
            }
          />
        </Stack>
      </Paper>

      <Paper sx={{ p: 3 }}>
        {adding ? (
          <RevisionForm
            employeeId={employee.id}
            onCancel={() => setAdding(false)}
            onSaved={() => {
              setAdding(false);
              void reload();
            }}
          />
        ) : (
          <Stack
            direction="row"
            sx={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}
          >
            <Typography variant="h6" component="h3">
              Salary history
            </Typography>
            <Button variant="contained" onClick={() => setAdding(true)}>
              Record salary revision
            </Button>
          </Stack>
        )}
        <Table size="small" aria-label="Salary history" sx={{ mt: 2 }}>
          <TableHead>
            <TableRow>
              <TableCell>Effective</TableCell>
              <TableCell>Currency</TableCell>
              <TableCell align="right">Base amount</TableCell>
              <TableCell>Components</TableCell>
              <TableCell>Reason</TableCell>
              <TableCell>Recorded by</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {revisions.map((revision) => (
              <TableRow key={revision.id}>
                <TableCell>{revision.effective_date}</TableCell>
                <TableCell>{revision.currency}</TableCell>
                <TableCell align="right">{revision.base_amount}</TableCell>
                <TableCell>
                  {revision.components
                    .map((c) => `${c.type} ${c.currency} ${c.amount}`)
                    .join(", ") || "—"}
                </TableCell>
                <TableCell>{revision.reason ?? "—"}</TableCell>
                <TableCell>{revision.recorded_by.email}</TableCell>
              </TableRow>
            ))}
            {revisions.length === 0 && (
              <TableRow>
                <TableCell colSpan={6}>No salary revisions recorded yet.</TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </Paper>

      <Paper sx={{ p: 3 }}>
        <Typography variant="h6" component="h3" gutterBottom>
          Change history
        </Typography>
        <Table size="small" aria-label="Change history">
          <TableHead>
            <TableRow>
              <TableCell>When</TableCell>
              <TableCell>Who</TableCell>
              <TableCell>What</TableCell>
              <TableCell>Changed</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {audit.map((entry, index) => (
              <TableRow key={`${entry.occurred_at}-${index}`}>
                <TableCell>{new Date(entry.occurred_at).toLocaleString()}</TableCell>
                <TableCell>{entry.actor?.email ?? "—"}</TableCell>
                <TableCell>
                  {entry.entity_type} {entry.action}
                </TableCell>
                <TableCell>{Object.keys(entry.new_values ?? {}).join(", ")}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Paper>
    </Stack>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <Stack>
      <Typography variant="caption" color="text.secondary">
        {label}
      </Typography>
      <Typography variant="body1">{value}</Typography>
    </Stack>
  );
}
