import { render, screen } from "@testing-library/react";
import { App } from "./App";

describe("App", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("shows the sign-in page when no one is signed in", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response(JSON.stringify({ error: { code: "not_signed_in", message: "Sign in" } }), {
            status: 401,
          }),
      ),
    );

    render(<App />);

    expect(await screen.findByRole("heading", { name: "Sign in" })).toBeInTheDocument();
  });
});
