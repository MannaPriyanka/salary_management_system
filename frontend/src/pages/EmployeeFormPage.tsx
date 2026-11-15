import { useEffect, useState, type FormEvent } from "react";
import { useNavigate, useParams } from "react-router";
import Alert from "@mui/material/Alert";
import Button from "@mui/material/Button";
import MenuItem from "@mui/material/MenuItem";
import Paper from "@mui/material/Paper";
import Stack from "@mui/material/Stack";
import TextField from "@mui/material/TextField";
import Typography from "@mui/material/Typography";
import {
  createEmployee,
  getEmployee,
  listNamed,
  updateEmployee,
  type EmployeeInput,
  type Named,
} from "../api/employees";
import { errorMessage, fieldErrors } from "../api/errors";

const EMPTY: EmployeeInput = {
  employee_code: "",
  full_name: "",
  work_email: "",
  department_id: "",
  designation_id: "",
  country_id: "",
  employment_status: "active",
  joining_date: "",
  exit_date: "",
};

export function EmployeeFormPage() {
  const { id } = useParams();
  const editing = Boolean(id);
  const navigate = useNavigate();
  const [values, setValues] = useState<EmployeeInput>(EMPTY);
  const [departments, setDepartments] = useState<Named[]>([]);
  const [designations, setDesignations] = useState<Named[]>([]);
  const [countries, setCountries] = useState<Named[]>([]);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    listNamed("departments").then((body) => setDepartments(body.data));
    listNamed("designations").then((body) => setDesignations(body.data));
    listNamed("countries").then((body) => setCountries(body.data));
  }, []);

  useEffect(() => {
    if (!id) return;
    getEmployee(Number(id)).then(({ data }) =>
      setValues({
        employee_code: data.employee_code,
        full_name: data.full_name,
        work_email: data.work_email,
        department_id: data.department.id,
        designation_id: data.designation.id,
        country_id: data.country.id,
        employment_status: data.employment_status,
        joining_date: data.joining_date,
        exit_date: data.exit_date ?? "",
      }),
    );
  }, [id]);

  function update<K extends keyof EmployeeInput>(key: K, value: EmployeeInput[K]) {
    setValues((current) => ({ ...current, [key]: value }));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setErrors({});
    setFormError(null);
    const payload = { ...values, exit_date: values.exit_date || null };
    try {
      const body = editing
        ? await updateEmployee(Number(id), { ...payload, employee_code: undefined })
        : await createEmployee(payload);
      navigate(`/employees/${body.data.id}`);
    } catch (caught) {
      setErrors(fieldErrors(caught));
      setFormError(errorMessage(caught));
    } finally {
      setSaving(false);
    }
  }

  const field = (key: keyof EmployeeInput, label: string, props: Record<string, unknown> = {}) => (
    <TextField
      label={label}
      value={values[key] ?? ""}
      onChange={(event) => update(key, event.target.value as never)}
      error={Boolean(errors[key])}
      helperText={errors[key]}
      fullWidth
      {...props}
    />
  );

  return (
    <Paper sx={{ p: 3, maxWidth: 800 }}>
      <Typography variant="h5" component="h2" gutterBottom>
        {editing ? "Edit employee" : "Add employee"}
      </Typography>
      <Stack component="form" spacing={2} onSubmit={handleSubmit} noValidate>
        {formError && <Alert severity="error">{formError}</Alert>}
        {field("employee_code", "Employee code", { disabled: editing, required: !editing })}
        {field("full_name", "Full name", { required: true })}
        {field("work_email", "Work email", { type: "email", required: true })}
        <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
          <TextField
            select
            label="Department"
            value={values.department_id}
            onChange={(e) => update("department_id", Number(e.target.value))}
            error={Boolean(errors.department_id)}
            helperText={errors.department_id}
            fullWidth
          >
            {departments.map((d) => (
              <MenuItem key={d.id} value={d.id}>
                {d.name}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            select
            label="Designation"
            value={values.designation_id}
            onChange={(e) => update("designation_id", Number(e.target.value))}
            error={Boolean(errors.designation_id)}
            helperText={errors.designation_id}
            fullWidth
          >
            {designations.map((d) => (
              <MenuItem key={d.id} value={d.id}>
                {d.name}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            select
            label="Country"
            value={values.country_id}
            onChange={(e) => update("country_id", Number(e.target.value))}
            error={Boolean(errors.country_id)}
            helperText={errors.country_id}
            fullWidth
          >
            {countries.map((c) => (
              <MenuItem key={c.id} value={c.id}>
                {c.name}
              </MenuItem>
            ))}
          </TextField>
        </Stack>
        <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
          <TextField
            select
            label="Employment status"
            value={values.employment_status}
            onChange={(e) =>
              update("employment_status", e.target.value as EmployeeInput["employment_status"])
            }
            fullWidth
          >
            <MenuItem value="active">Active</MenuItem>
            <MenuItem value="on_leave">On leave</MenuItem>
            <MenuItem value="exited">Exited</MenuItem>
          </TextField>
          {field("joining_date", "Joining date", {
            type: "date",
            InputLabelProps: { shrink: true },
            required: true,
          })}
          {field("exit_date", "Exit date", {
            type: "date",
            slotProps: { inputLabel: { shrink: true } },
          })}
        </Stack>
        <Stack
          direction="row"
          spacing={2}
          sx={{ flexDirection: "row", justifyContent: "flex-end" }}
        >
          <Button onClick={() => navigate(-1)}>Cancel</Button>
          <Button type="submit" variant="contained" disabled={saving}>
            {saving ? "Saving…" : "Save"}
          </Button>
        </Stack>
      </Stack>
    </Paper>
  );
}
