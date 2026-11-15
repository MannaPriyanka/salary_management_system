import { useEffect, useState } from "react";
import { Link as RouterLink, useNavigate } from "react-router";
import Alert from "@mui/material/Alert";
import Box from "@mui/material/Box";
import Button from "@mui/material/Button";
import Checkbox from "@mui/material/Checkbox";
import FormControlLabel from "@mui/material/FormControlLabel";
import MenuItem from "@mui/material/MenuItem";
import Paper from "@mui/material/Paper";
import Stack from "@mui/material/Stack";
import Table from "@mui/material/Table";
import TableBody from "@mui/material/TableBody";
import TableCell from "@mui/material/TableCell";
import TableHead from "@mui/material/TableHead";
import TableRow from "@mui/material/TableRow";
import TextField from "@mui/material/TextField";
import Typography from "@mui/material/Typography";
import { listEmployees, listNamed, type EmployeeSummary, type Named } from "../api/employees";
import { errorMessage } from "../api/errors";

export function EmployeesPage() {
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const [departmentId, setDepartmentId] = useState("");
  const [status, setStatus] = useState("");
  const [includeArchived, setIncludeArchived] = useState(false);
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState<EmployeeSummary[]>([]);
  const [totalPages, setTotalPages] = useState(1);
  const [departments, setDepartments] = useState<Named[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    listNamed("departments")
      .then((body) => setDepartments(body.data))
      .catch(() => setDepartments([]));
  }, []);

  useEffect(() => {
    let active = true;
    listEmployees({
      q: query,
      department_id: departmentId,
      employment_status: status,
      include_archived: includeArchived,
      page,
    })
      .then((body) => {
        if (!active) return;
        setRows(body.data);
        setTotalPages(body.meta.total_pages ?? 1);
        setError(null);
      })
      .catch((caught: unknown) => active && setError(errorMessage(caught)))
      .finally(() => active && setLoading(false));
    return () => {
      active = false;
    };
  }, [query, departmentId, status, includeArchived, page]);

  return (
    <Stack spacing={3}>
      <Stack
        direction="row"
        sx={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}
      >
        <Typography variant="h5" component="h2">
          Employees
        </Typography>
        <Button variant="contained" component={RouterLink} to="/employees/new">
          Add employee
        </Button>
      </Stack>

      <Paper sx={{ p: 2 }}>
        <Stack
          direction={{ xs: "column", md: "row" }}
          spacing={2}
          sx={{ alignItems: { md: "center" } }}
        >
          <TextField
            label="Search by name or code"
            value={query}
            onChange={(event) => {
              setPage(1);
              setQuery(event.target.value);
            }}
            size="small"
          />
          <TextField
            select
            label="Department"
            value={departmentId}
            onChange={(event) => {
              setPage(1);
              setDepartmentId(event.target.value);
            }}
            size="small"
            sx={{ minWidth: 180 }}
          >
            <MenuItem value="">All departments</MenuItem>
            {departments.map((department) => (
              <MenuItem key={department.id} value={String(department.id)}>
                {department.name}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            select
            label="Status"
            value={status}
            onChange={(event) => {
              setPage(1);
              setStatus(event.target.value);
            }}
            size="small"
            sx={{ minWidth: 160 }}
          >
            <MenuItem value="">Any status</MenuItem>
            <MenuItem value="active">Active</MenuItem>
            <MenuItem value="on_leave">On leave</MenuItem>
            <MenuItem value="exited">Exited</MenuItem>
          </TextField>
          <FormControlLabel
            control={
              <Checkbox
                checked={includeArchived}
                onChange={(event) => {
                  setPage(1);
                  setIncludeArchived(event.target.checked);
                }}
              />
            }
            label="Include archived"
          />
        </Stack>
      </Paper>

      {error && <Alert severity="error">{error}</Alert>}

      <Paper>
        <Table size="small" aria-label="Employees">
          <TableHead>
            <TableRow>
              <TableCell>Code</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Department</TableCell>
              <TableCell>Country</TableCell>
              <TableCell>Status</TableCell>
              <TableCell align="right">Current salary</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((employee) => (
              <TableRow
                key={employee.id}
                hover
                sx={{ cursor: "pointer" }}
                onClick={() => navigate(`/employees/${employee.id}`)}
              >
                <TableCell>{employee.employee_code}</TableCell>
                <TableCell>
                  {employee.full_name}
                  {employee.archived && " (archived)"}
                </TableCell>
                <TableCell>{employee.department.name}</TableCell>
                <TableCell>{employee.country.name}</TableCell>
                <TableCell>{employee.employment_status}</TableCell>
                <TableCell align="right">
                  {employee.current_salary
                    ? `${employee.current_currency} ${employee.current_salary}`
                    : "No salary yet"}
                </TableCell>
              </TableRow>
            ))}
            {!loading && rows.length === 0 && (
              <TableRow>
                <TableCell colSpan={6}>No employees match these filters.</TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </Paper>

      <Box sx={{ display: "flex", justifyContent: "flex-end", alignItems: "center", gap: 2 }}>
        <Button disabled={page <= 1} onClick={() => setPage((current) => current - 1)}>
          Previous
        </Button>
        <Typography variant="body2">
          Page {page} of {Math.max(totalPages, 1)}
        </Typography>
        <Button disabled={page >= totalPages} onClick={() => setPage((current) => current + 1)}>
          Next
        </Button>
      </Box>
    </Stack>
  );
}
