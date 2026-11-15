import { apiRequest, ApiError } from "./client";

describe("apiRequest", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("returns the parsed body on success", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify({ data: { id: 1 } }), { status: 200 })),
    );
    await expect(apiRequest("/employees/1")).resolves.toEqual({ data: { id: 1 } });
  });

  it("returns undefined for a 204 response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(null, { status: 204 })),
    );
    await expect(apiRequest("/session", { method: "DELETE" })).resolves.toBeUndefined();
  });

  it("turns the server error envelope into an ApiError with code, message, and details", async () => {
    const body = {
      error: {
        code: "validation_failed",
        message: "One or more fields are invalid.",
        details: [{ field: "full_name", message: "can't be blank" }],
      },
    };
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify(body), { status: 422 })),
    );

    const error = await apiRequest("/employees", { method: "POST", body: {} }).catch(
      (caught: unknown) => caught,
    );

    expect(error).toBeInstanceOf(ApiError);
    expect(error).toMatchObject({ status: 422, code: "validation_failed" });
    expect((error as ApiError).details[0]).toMatchObject({ field: "full_name" });
  });

  it("sends the same-origin session cookie and a JSON body", async () => {
    const fetchMock = vi.fn(async () => new Response("{}", { status: 201 }));
    vi.stubGlobal("fetch", fetchMock);

    await apiRequest("/employees", { method: "POST", body: { full_name: "Asha" } });

    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("/api/v1/employees");
    expect(init.credentials).toBe("same-origin");
    expect(init.body).toBe(JSON.stringify({ full_name: "Asha" }));
  });
});
