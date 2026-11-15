import { useEffect, useState } from "react";
import Alert from "@mui/material/Alert";
import Grid from "@mui/material/Grid";
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
import { getBreakdown, getSummary, type Breakdown, type StatsRow } from "../api/statistics";
import { errorMessage } from "../api/errors";

const DIMENSION_LABELS: Record<Breakdown, string> = {
  department: "Department",
  country: "Country",
  designation: "Designation",
};

export function StatisticsPage() {
  const [summary, setSummary] = useState<StatsRow[]>([]);
  const [by, setBy] = useState<Breakdown>("department");
  const [rows, setRows] = useState<StatsRow[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    Promise.all([getSummary(), getBreakdown(by)])
      .then(([summaryBody, breakdownBody]) => {
        if (cancelled) return;
        setSummary(summaryBody.data);
        setRows(breakdownBody.data);
        setError(null);
      })
      .catch((caught: unknown) => !cancelled && setError(errorMessage(caught)));
    return () => {
      cancelled = true;
    };
  }, [by]);

  return (
    <Stack spacing={3}>
      <Typography variant="h5" component="h2">
        Pay statistics
      </Typography>
      <Typography variant="body2" color="text.secondary">
        Current base salaries of employed, non-archived employees. Figures are shown per currency
        and are never added together across currencies.
      </Typography>

      {error && <Alert severity="error">{error}</Alert>}

      <Grid container spacing={2}>
        {summary.map((row) => (
          <Grid key={row.currency} size={{ xs: 12, md: 6 }}>
            <Paper sx={{ p: 2 }} aria-label={`Summary in ${row.currency}`}>
              <Typography variant="h6" component="h3">
                {row.currency} · {row.headcount} employees
              </Typography>
              <Typography variant="body2">Total base: {row.total_base}</Typography>
              <Typography variant="body2">Average: {row.average_base}</Typography>
              <Typography variant="body2">Median: {row.median_base}</Typography>
              <Typography variant="body2">
                Range: {row.min_base} to {row.max_base}
              </Typography>
            </Paper>
          </Grid>
        ))}
        {summary.length === 0 && !error && (
          <Grid size={12}>
            <Typography variant="body2">No employees have a salary in force today.</Typography>
          </Grid>
        )}
      </Grid>

      <Paper sx={{ p: 2 }}>
        <TextField
          select
          label="Break down by"
          value={by}
          onChange={(event) => setBy(event.target.value as Breakdown)}
          size="small"
          sx={{ mb: 2, minWidth: 200 }}
        >
          {(Object.keys(DIMENSION_LABELS) as Breakdown[]).map((key) => (
            <MenuItem key={key} value={key}>
              {DIMENSION_LABELS[key]}
            </MenuItem>
          ))}
        </TextField>
        <Table size="small" aria-label="Breakdown">
          <TableHead>
            <TableRow>
              <TableCell>{DIMENSION_LABELS[by]}</TableCell>
              <TableCell>Currency</TableCell>
              <TableCell align="right">Headcount</TableCell>
              <TableCell align="right">Total base</TableCell>
              <TableCell align="right">Average</TableCell>
              <TableCell align="right">Median</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((row) => (
              <TableRow key={`${row.group?.id}-${row.currency}`}>
                <TableCell>{row.group?.name}</TableCell>
                <TableCell>{row.currency}</TableCell>
                <TableCell align="right">{row.headcount}</TableCell>
                <TableCell align="right">{row.total_base}</TableCell>
                <TableCell align="right">{row.average_base}</TableCell>
                <TableCell align="right">{row.median_base}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Paper>
    </Stack>
  );
}
