import { useEffect, useState, type FormEvent } from "react";
import Alert from "@mui/material/Alert";
import Button from "@mui/material/Button";
import MenuItem from "@mui/material/MenuItem";
import Stack from "@mui/material/Stack";
import TextField from "@mui/material/TextField";
import Typography from "@mui/material/Typography";
import { createRevision, listCurrencies, type Component, type Revision } from "../api/employees";
import { errorMessage, fieldErrors } from "../api/errors";

interface Props {
  employeeId: number;
  onSaved: (revision: Revision) => void;
  onCancel: () => void;
}

// Amounts are kept as text end to end. They are sent as strings and never converted to numbers here.
export function RevisionForm({ employeeId, onSaved, onCancel }: Props) {
  const [currencies, setCurrencies] = useState<Array<{ code: string; minor_units: number }>>([]);
  const [currency, setCurrency] = useState("INR");
  const [baseAmount, setBaseAmount] = useState("");
  const [effectiveDate, setEffectiveDate] = useState("");
  const [reason, setReason] = useState("");
  const [allowance, setAllowance] = useState("");
  const [bonus, setBonus] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    listCurrencies()
      .then((body) => setCurrencies(body.data))
      .catch(() => setCurrencies([]));
  }, []);

  function components(): Component[] {
    const list: Component[] = [];
    if (allowance.trim()) list.push({ type: "allowance", amount: allowance.trim(), currency });
    if (bonus.trim()) list.push({ type: "bonus", amount: bonus.trim(), currency });
    return list;
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setErrors({});
    setFormError(null);
    try {
      const body = await createRevision(employeeId, {
        currency,
        base_amount: baseAmount.trim(),
        effective_date: effectiveDate,
        reason,
        components: components(),
      });
      onSaved(body.data);
    } catch (caught) {
      setErrors(fieldErrors(caught));
      setFormError(errorMessage(caught));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Stack
      component="form"
      spacing={2}
      onSubmit={handleSubmit}
      noValidate
      aria-label="Record salary revision"
    >
      <Typography variant="h6" component="h3">
        Record salary revision
      </Typography>
      {formError && <Alert severity="error">{formError}</Alert>}
      <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
        <TextField
          select
          label="Currency"
          value={currency}
          onChange={(event) => setCurrency(event.target.value)}
          error={Boolean(errors.currency)}
          helperText={errors.currency}
          sx={{ minWidth: 140 }}
        >
          {currencies.map((item) => (
            <MenuItem key={item.code} value={item.code}>
              {item.code}
            </MenuItem>
          ))}
        </TextField>
        <TextField
          label="Base amount"
          value={baseAmount}
          onChange={(event) => setBaseAmount(event.target.value)}
          error={Boolean(errors.base_amount)}
          helperText={errors.base_amount}
          required
          fullWidth
        />
        <TextField
          label="Effective date"
          type="date"
          value={effectiveDate}
          onChange={(event) => setEffectiveDate(event.target.value)}
          error={Boolean(errors.effective_date)}
          helperText={errors.effective_date}
          slotProps={{ inputLabel: { shrink: true } }}
          required
        />
      </Stack>
      <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
        <TextField
          label="Allowance (optional)"
          value={allowance}
          onChange={(event) => setAllowance(event.target.value)}
          error={Boolean(errors.components)}
          fullWidth
        />
        <TextField
          label="Bonus (optional)"
          value={bonus}
          onChange={(event) => setBonus(event.target.value)}
          fullWidth
        />
      </Stack>
      <TextField
        label="Reason"
        value={reason}
        onChange={(event) => setReason(event.target.value)}
        slotProps={{ htmlInput: { maxLength: 500 } }}
      />
      <Stack direction="row" spacing={2} sx={{ flexDirection: "row", justifyContent: "flex-end" }}>
        <Button onClick={onCancel}>Cancel</Button>
        <Button type="submit" variant="contained" disabled={saving}>
          {saving ? "Saving…" : "Save revision"}
        </Button>
      </Stack>
    </Stack>
  );
}
