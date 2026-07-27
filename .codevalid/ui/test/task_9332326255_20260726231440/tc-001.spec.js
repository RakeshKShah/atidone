import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMocks } from "../../mock/mock-server.js";

test("tc-001 Home page loads for visitor", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "tc-001",
    testTitle: "Home page loads for visitor",
  });

  await recorder.step("Set up unauthenticated mock routes");
  await setupMocks(page);

  await recorder.step("Navigate to the home page");
  await page.goto("/");

  await recorder.step("Wait for the landing content to be visible");
  await expect(page.getByText("Welcome to Atidone.")).toBeVisible();

  await recorder.step("Assert primary brand content is rendered");
  await expect(page.getByRole("link", { name: "Atidone" })).toBeVisible();
  await expect(
    page.getByText("No personal information regarding your GitHub account are stored in database.")
  ).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:tc-001");
  await recorder.save(testInfo);
});
