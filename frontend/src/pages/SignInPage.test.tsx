import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router";
import { ApiError } from "../api/client";
import { AuthProvider } from "../auth/AuthContext";
import { SignInPage, signInMessage } from "./SignInPage";

function renderSignIn() {
  return render(
    <AuthProvider>
      <MemoryRouter initialEntries={["/sign-in"]}>
        <Routes>
          <Route path="/sign-in" element={<SignInPage />} />
          <Route path="/employees" element={<p>Employees screen</p>} />
        </Routes>
      </MemoryRouter>
    </AuthProvider>,
  );
}

describe("signInMessage", () => {
  it("explains throttling without revealing whether the account exists", () => {
    expect(signInMessage(new ApiError(429, "sign_in_refused", "x"))).toMatch(
      /too many failed attempts/i,
    );
  });

  it("uses the same message for every wrong credential", () => {
    expect(signInMessage(new ApiError(401, "invalid_credentials", "x"))).toBe(
      "Invalid email or password.",
    );
  });
});

describe("SignInPage", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("shows an error for wrong credentials and stays on the page", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: string, init?: RequestInit) => {
        if (init?.method === "POST") {
          return new Response(
            JSON.stringify({
              error: { code: "invalid_credentials", message: "Invalid email or password." },
            }),
            { status: 401 },
          );
        }
        return new Response(
          JSON.stringify({ error: { code: "not_signed_in", message: "Sign in is required." } }),
          { status: 401 },
        );
      }),
    );

    renderSignIn();
    fireEvent.change(await screen.findByLabelText(/work email/i), {
      target: { value: "hr@example.test" },
    });
    fireEvent.change(screen.getByLabelText(/password/i), {
      target: { value: "wrong password here" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign in" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Invalid email or password.");
  });

  it("opens the employees screen after a successful sign-in", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: string, init?: RequestInit) => {
        if (init?.method === "POST") {
          return new Response(JSON.stringify({ data: { id: 1, email: "hr@example.test" } }), {
            status: 201,
          });
        }
        return new Response(
          JSON.stringify({ error: { code: "not_signed_in", message: "Sign in is required." } }),
          { status: 401 },
        );
      }),
    );

    renderSignIn();
    fireEvent.change(await screen.findByLabelText(/work email/i), {
      target: { value: "hr@example.test" },
    });
    fireEvent.change(screen.getByLabelText(/password/i), {
      target: { value: "correct horse battery staple" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign in" }));

    await waitFor(() => expect(screen.getByText("Employees screen")).toBeInTheDocument());
  });
});
