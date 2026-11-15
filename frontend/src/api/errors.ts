import { ApiError } from "./client";

// Turns any error from the API layer into a sentence a person can act on.
export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    const detail = error.details.find((item) => typeof item.message === "string")?.message;
    return detail ? `${error.message} ${detail}` : error.message;
  }
  return "Something went wrong. Please try again.";
}

// Maps server field errors to form field names, so each message appears under its field.
export function fieldErrors(error: unknown): Record<string, string> {
  if (!(error instanceof ApiError)) return {};
  return error.details.reduce<Record<string, string>>((acc, item) => {
    if (item.field && typeof item.message === "string") acc[item.field] = item.message;
    return acc;
  }, {});
}
