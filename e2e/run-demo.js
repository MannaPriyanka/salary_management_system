// Browser walkthrough of every feature of the Salary Management application.
//
// Usage (from this folder):
//   npm install && npx playwright install chromium
//   npm run demo                      # visible browser, slowed down, records a video
//   npm run demo:fast                 # no slow motion or pauses
//
// Environment variables (all optional):
//   BASE_URL       default http://127.0.0.1:3000 (the Rails server)
//   HR_EMAIL       default hr.manager@example.test
//   HR_PASSWORD    default the development password
//   HEADLESS       "true" to hide the browser (default: visible)
//   SLOW_MO        milliseconds added to each browser action (default 700)
//   PAUSE_MS       milliseconds to hold each feature's banner (default 2500)
//   OUTPUT_DIR     default ./demo-output
//
// Outputs in OUTPUT_DIR: summary.md, summary.json, screenshots/, and a video (.webm).

const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const CONFIG = {
  baseUrl: process.env.BASE_URL || "http://127.0.0.1:3000",
  email: process.env.HR_EMAIL || "hr.manager@example.test",
  password: process.env.HR_PASSWORD || "development-only-password-do-not-use",
  headless: process.env.HEADLESS === "true",
  slowMo: Number(process.env.SLOW_MO ?? 700),
  pauseMs: Number(process.env.PAUSE_MS ?? 2500),
  outputDir: path.resolve(process.env.OUTPUT_DIR || path.join(__dirname, "demo-output")),
};

const RUN = Date.now().toString().slice(-6);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// ---------- shared helpers used by the features ----------

async function showBanner(page, text) {
  await page.evaluate((message) => {
    let banner = document.getElementById("demo-banner");
    if (!banner) {
      banner = document.createElement("div");
      banner.id = "demo-banner";
      Object.assign(banner.style, {
        position: "fixed", top: "12px", left: "50%", transform: "translateX(-50%)", zIndex: "99999",
        pointerEvents: "none",
        background: "#1f4e79", color: "#fff", padding: "10px 18px", borderRadius: "8px",
        fontFamily: "Roboto, Arial, sans-serif", fontSize: "16px", boxShadow: "0 4px 14px rgba(0,0,0,.3)",
      });
      document.body.appendChild(banner);
    }
    banner.textContent = message;
  }, text).catch(() => {});
}

async function pickOption(page, label, option) {
  await page.getByLabel(label).click();
  await page.getByRole("option", { name: option, exact: true }).click();
}

// Fills the employee form and clicks Save. The caller checks where the app ends up.
async function fillEmployee(page, { code, name, email, exitDate, status }) {
  await page.getByLabel("Employee code").fill(code);
  await page.getByLabel("Full name").fill(name);
  await page.getByLabel("Work email").fill(email);
  await pickOption(page, "Department", "Engineering");
  await page.getByLabel("Designation").click();
  await page.getByRole("option").first().click();
  await pickOption(page, "Country", "India");
  await page.getByLabel("Joining date").fill("2020-01-15");
  if (status) await pickOption(page, "Employment status", status);
  if (exitDate) await page.getByLabel("Exit date").fill(exitDate);
  await page.getByRole("button", { name: "Save" }).click();
}

async function expectEmployeePage(page, name) {
  await page.waitForURL(/\/employees\/\d+$/);
  await page.getByRole("heading", { name }).waitFor();
}

async function signIn(page, password) {
  await page.getByLabel("Work email").fill(CONFIG.email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign in" }).click();
}

// ---------- the features, in the order they are shown ----------

const features = [
  {
    name: "Sign-in is refused for a wrong password",
    run: async (ctx) => {
      await ctx.page.goto(`${CONFIG.baseUrl}/employees`);
      await ctx.page.waitForURL(/\/sign-in/);
      await signIn(ctx.page, "this is the wrong password");
      await ctx.page.getByRole("alert").filter({ hasText: "Invalid email or password." }).waitFor();
    },
  },
  {
    name: "HR Manager signs in and opens the employee list",
    run: async (ctx) => {
      await signIn(ctx.page, CONFIG.password);
      await ctx.page.waitForURL(/\/employees$/);
      await ctx.page.getByRole("heading", { name: "Employees" }).waitFor();
      await ctx.page.getByRole("table", { name: "Employees" }).locator("tbody tr").first().waitFor();
    },
  },
  {
    name: "Employee list shows salaries per currency and search narrows it",
    run: async (ctx) => {
      const table = ctx.page.getByRole("table", { name: "Employees" });
      const firstRow = await table.locator("tbody tr").first().innerText();
      if (!/EMP\d{5}/.test(firstRow)) throw new Error("first row has no employee code");
      const searched = ctx.page.waitForResponse((r) => r.url().includes("q=EMP00010") && r.status() === 200);
      await ctx.page.getByLabel("Search by name or code").fill("EMP00010");
      await searched;
      const rows = await table.locator("tbody tr").count();
      if (rows !== 1) throw new Error(`search returned ${rows} rows, expected 1`);
      await ctx.page.getByLabel("Search by name or code").fill("");
    },
  },
  {
    name: "Add an employee",
    run: async (ctx) => {
      ctx.code = `EMP8${RUN}`;
      ctx.name = `Demo Employee ${RUN}`;
      ctx.email = `demo.${RUN}@example.test`;
      await ctx.page.getByRole("link", { name: "Add employee" }).click();
      await ctx.page.getByRole("heading", { name: "Add employee" }).waitFor();
      await fillEmployee(ctx.page, { code: ctx.code, name: ctx.name, email: ctx.email });
      await expectEmployeePage(ctx.page, ctx.name);
      ctx.employeeUrl = ctx.page.url();
    },
  },
  {
    name: "A duplicate employee code is refused",
    run: async (ctx) => {
      await ctx.page.getByRole("link", { name: "Employees" }).first().click();
      await ctx.page.getByRole("link", { name: "Add employee" }).click();
      await fillEmployee(ctx.page, { code: ctx.code, name: "Someone Else", email: `other.${RUN}@example.test` });
      await ctx.page.getByRole("alert").filter({ hasText: /already in use/ }).waitFor();
      await ctx.page.getByRole("link", { name: "Employees" }).first().click();
    },
  },
  {
    name: "Record a salary revision with an allowance",
    run: async (ctx) => {
      await ctx.page.goto(ctx.employeeUrl);
      await ctx.page.getByRole("button", { name: "Record salary revision" }).click();
      await ctx.page.getByLabel("Base amount").fill("150000.50");
      await ctx.page.getByLabel("Effective date").fill("2021-06-01");
      await ctx.page.getByLabel("Allowance (optional)").fill("5000.00");
      await ctx.page.getByLabel("Reason").fill("Promotion");
      await ctx.page.getByRole("button", { name: "Save revision" }).click();
      await ctx.page.getByRole("cell", { name: "150000.50" }).waitFor();
      await ctx.page.getByRole("cell", { name: "allowance INR 5000.00" }).waitFor();
    },
  },
  {
    name: "An amount with too many decimals is explained under its field",
    run: async (ctx) => {
      await ctx.page.goto(ctx.employeeUrl);
      await ctx.page.getByRole("button", { name: "Record salary revision" }).click();
      await ctx.page.getByLabel("Base amount").fill("1000.005");
      await ctx.page.getByLabel("Effective date").fill("2022-01-01");
      await ctx.page.getByRole("button", { name: "Save revision" }).click();
      await ctx.page.getByText("must have at most 2 decimal places").waitFor();
      await ctx.page.getByRole("button", { name: "Cancel" }).click();
    },
  },
  {
    name: "An exited employee can be archived and restored",
    run: async (ctx) => {
      const exitedCode = `EMP7${RUN}`;
      const exitedName = `Exited Demo ${RUN}`;
      await ctx.page.getByRole("link", { name: "Employees" }).first().click();
      await ctx.page.getByRole("link", { name: "Add employee" }).click();
      await fillEmployee(ctx.page, {
        code: exitedCode, name: exitedName, email: `exited.${RUN}@example.test`,
        status: "Exited", exitDate: "2024-12-31",
      });
      await expectEmployeePage(ctx.page, exitedName);
      await ctx.page.getByRole("button", { name: "Archive" }).click();
      await ctx.page.getByRole("heading", { name: `${exitedName} (archived)` }).waitFor();
      await ctx.page.getByRole("button", { name: "Restore" }).click();
      await ctx.page.getByRole("heading", { name: exitedName, exact: true }).waitFor();
    },
  },
  {
    name: "Change history records who changed what",
    run: async (ctx) => {
      await ctx.page.goto(ctx.employeeUrl);
      const history = ctx.page.getByRole("table", { name: "Change history" });
      await history.getByText("SalaryRevision create").first().waitFor();
      await history.getByText("Employee create").first().waitFor();
    },
  },
  {
    name: "Pay statistics: current figures per currency",
    run: async (ctx) => {
      await ctx.page.getByRole("link", { name: "Pay statistics" }).click();
      await ctx.page.getByRole("heading", { name: "Pay statistics" }).waitFor();
      const lines = [];
      for (const currency of ["INR", "USD", "EUR", "GBP"]) {
        const card = ctx.page.getByLabel(`Summary in ${currency}`);
        await card.waitFor();
        await showBanner(ctx.page, `Pay statistics: ${currency} figures`);
        await ctx.page.waitForTimeout(CONFIG.pauseMs);
        const text = (await card.innerText()).replace(/\s+/g, " ").trim();
        lines.push(text);
      }
      ctx.detail = lines.join("  |  ");
    },
  },
  {
    name: "Pay statistics: breakdown by department, country and designation",
    run: async (ctx) => {
      const table = ctx.page.getByRole("table", { name: "Breakdown" });
      const summaries = [];
      for (const dimension of ["Department", "Country", "Designation"]) {
        await ctx.page.getByLabel("Break down by").click();
        await ctx.page.getByRole("option", { name: dimension, exact: true }).click();
        await ctx.page.getByRole("columnheader", { name: dimension, exact: true }).waitFor();
        await table.locator("tbody tr").first().waitFor();
        const rows = await table.locator("tbody tr").count();
        if (rows === 0) throw new Error(`no rows for breakdown by ${dimension}`);
        await showBanner(ctx.page, `Pay statistics: by ${dimension.toLowerCase()} (${rows} rows)`);
        await ctx.page.waitForTimeout(CONFIG.pauseMs);
        summaries.push(`${dimension}: ${rows} rows`);
      }
      ctx.detail = summaries.join("; ");
    },
  },
  {
    name: "Signing out ends the session and protects the app",
    run: async (ctx) => {
      await ctx.page.getByRole("button", { name: "Sign out" }).click();
      await ctx.page.waitForURL(/\/sign-in/);
      await ctx.page.goto(`${CONFIG.baseUrl}/employees`);
      await ctx.page.waitForURL(/\/sign-in/);
    },
  },
];

// ---------- runner and report ----------

async function main() {
  fs.mkdirSync(path.join(CONFIG.outputDir, "screenshots"), { recursive: true });
  const videoDir = path.join(CONFIG.outputDir, "video");
  fs.mkdirSync(videoDir, { recursive: true });

  const browser = await chromium.launch({ headless: CONFIG.headless, slowMo: CONFIG.slowMo });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 860 },
    recordVideo: { dir: videoDir, size: { width: 1280, height: 860 } },
  });
  const page = await context.newPage();
  const video = page.video();
  page.setDefaultTimeout(15000);
  const ctx = { page };
  const results = [];

  console.log(`\nSalary Management walkthrough against ${CONFIG.baseUrl}\n`);

  for (let index = 0; index < features.length; index++) {
    const feature = features[index];
    const number = index + 1;
    const label = `Feature ${number}/${features.length}: ${feature.name}`;
    const started = Date.now();
    let status = "PASSED";
    let error = "";

    console.log(label);
    await showBanner(page, label);
    await sleep(CONFIG.pauseMs);

    ctx.detail = "";
    try {
      await feature.run(Object.assign(ctx, { featureName: feature.name }));
    } catch (caught) {
      status = "FAILED";
      error = String(caught.message || caught).split("\n").filter((line) => line.trim()).slice(0, 3).join(" | ");
    }

    const screenshot = path.join("screenshots", `${String(number).padStart(2, "0")}-${slug(feature.name)}.png`);
    await page.screenshot({ path: path.join(CONFIG.outputDir, screenshot) }).catch(() => {});
    const durationMs = Date.now() - started;
    results.push({ number, name: feature.name, status, durationMs, error, screenshot, detail: ctx.detail });
    console.log(`  -> ${status}${error ? `: ${error}` : ""}\n`);

    // Leave the app in a known place before the next feature.
    await page.goto(CONFIG.baseUrl + "/employees").catch(() => {});
  }

  await context.close();
  const videoPath = video ? await video.path() : null;
  await browser.close();

  const finalVideo = videoPath ? path.join(CONFIG.outputDir, `demo-run-${RUN}.webm`) : null;
  if (videoPath && finalVideo) fs.renameSync(videoPath, finalVideo);

  writeReports(results, finalVideo);
  const failed = results.filter((r) => r.status === "FAILED").length;
  console.log(`Result: ${results.length - failed} passed, ${failed} failed`);
  console.log(`Summary: ${path.join(CONFIG.outputDir, "summary.md")}`);
  if (finalVideo) console.log(`Video:   ${finalVideo}`);
  process.exitCode = failed ? 1 : 0;
}

function slug(text) {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "").slice(0, 60);
}

function writeReports(results, videoPath) {
  const passed = results.filter((r) => r.status === "PASSED").length;
  const lines = [
    "# Salary Management: feature walkthrough",
    "",
    `Run: ${new Date().toISOString()}  ·  Target: ${CONFIG.baseUrl}`,
    "",
    `**${passed} of ${results.length} features passed.**`,
    "",
    "| # | Feature | Result | Time | Screenshot |",
    "|---|---|---|---|---|",
    ...results.map((r) => {
      const mark = r.status === "PASSED" ? "PASSED" : "FAILED";
      return `| ${r.number} | ${r.name} | ${mark} | ${(r.durationMs / 1000).toFixed(1)} s | ${r.screenshot} |`;
    }),
  ];
  const failures = results.filter((r) => r.status === "FAILED");
  const withDetail = results.filter((r) => r.detail);
  if (withDetail.length) {
    lines.push("", "## Figures recorded", "", ...withDetail.map((r) => `- **${r.name}**: ${r.detail}`));
  }
  if (failures.length) {
    lines.push("", "## Failures", "", ...failures.map((r) => `- **${r.name}**: ${r.error}`));
  }
  if (videoPath) lines.push("", `Video: ${path.basename(videoPath)}`);
  fs.writeFileSync(path.join(CONFIG.outputDir, "summary.md"), lines.join("\n") + "\n");
  fs.writeFileSync(
    path.join(CONFIG.outputDir, "summary.json"),
    JSON.stringify({ baseUrl: CONFIG.baseUrl, passed, total: results.length, features: results, video: videoPath }, null, 2),
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
