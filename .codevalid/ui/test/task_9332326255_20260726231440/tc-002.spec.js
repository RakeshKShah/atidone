import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMocks } from "../../mock/mock-server.js";

test("tc-002 Home page sign-in affordance", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "tc-002",
    testTitle: "Home page sign-in affordance",
  });

  await recorder.step("Set up unauthenticated mock routes");
  await setupMocks(page);

  await recorder.step("Navigate to the home page");
  await page.goto("/");

  await recorder.step("Locate the GitHub sign-in control");
  const signInControl = page.getByRole("link", { name: "Login with GitHub" });

  await recorder.step("Assert the sign-in control is visible and enabled");
  await expect(signInControl).toBeVisible();
  await expect(signInControl).toBeEnabled();
  await expect(signInControl).toHaveAttribute("href", "/api/auth/github");

  console.log("CODEVALID_TEST_ASSERTION_OK:tc-002");
  await recorder.save(testInfo);
});
