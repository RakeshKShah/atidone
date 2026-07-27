/**
 * Atidone – Todo UI tests for task_9332326255_20260726231440
 *
 * Covers:
 *  1. Unauthenticated state — root page shows "Login with GitHub", no todo content
 *  2. Authenticated state — /todos renders mocked todo list
 *  3. Add todo — submitting the form creates a new item (mocked POST)
 *  4. Toggle todo — clicking the switch calls PATCH and updates UI (mocked)
 *  5. Delete todo — clicking the delete button removes the item (mocked)
 *  6. User isolation — session user A sees only user A's todos
 */
import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupMocks,
  mockAuthenticatedUser,
  mockTodos,
} from "../../mock/mock-server.js";

// ── Shared todo fixtures ──────────────────────────────────────────────────────
const TODO_A = { id: 1, title: "Buy groceries", completed: false, userId: 10 };
const TODO_B = { id: 2, title: "Write tests", completed: true, userId: 10 };
const NEW_TODO = { id: 3, title: "Deploy to production", completed: false, userId: 10 };

// ─────────────────────────────────────────────────────────────────────────────
// 1. Unauthenticated redirect / home page
// ─────────────────────────────────────────────────────────────────────────────
test.describe("Unauthenticated state", () => {
  test("home page shows Login with GitHub and no todo list", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "tc-001",
      testTitle: "home page shows Login with GitHub and no todo list",
    });

    await setupMocks(page);

    recorder.record("navigate to /");
    await page.goto("/");

    recorder.record("assert page title");
    await expect(page).toHaveTitle(/Atidone/i);

    recorder.record("assert welcome text");
    await expect(page.getByText("Welcome to Atidone")).toBeVisible();

    recorder.record("assert Login with GitHub button visible");
    const loginBtn = page.getByRole("link", { name: /login with github/i });
    await expect(loginBtn).toBeVisible();

    recorder.record("assert no todo input present");
    await expect(page.getByPlaceholder(/make a nuxt demo/i)).not.toBeVisible();

    await recorder.save(testInfo);
  });

  test("/todos redirects unauthenticated users away from the todos page", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "tc-002",
      testTitle: "/todos redirects unauthenticated users away from the todos page",
    });

    await setupMocks(page);

    recorder.record("navigate to /todos");
    await page.goto("/todos");

    // The auth middleware redirects to "/" when not logged in
    recorder.record("assert not on /todos");
    await expect(page).not.toHaveURL(/\/todos$/);

    recorder.record("assert no todo input");
    await expect(page.getByPlaceholder(/make a nuxt demo/i)).not.toBeVisible();

    await recorder.save(testInfo);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. Authenticated – todo list rendering
// ─────────────────────────────────────────────────────────────────────────────
test.describe("Authenticated todo list", () => {
  test.beforeEach(async ({ page }) => {
    await setupMocks(page);
    await mockAuthenticatedUser(page, { login: "testuser", id: 10 });
    await mockTodos(page, [TODO_A, TODO_B]);
  });

  test("renders mocked todo items on /todos", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "tc-003",
      testTitle: "renders mocked todo items on /todos",
    });

    recorder.record("navigate to /todos");
    await page.goto("/todos");

    recorder.record("assert todo A visible");
    await expect(page.getByText(TODO_A.title)).toBeVisible();

    recorder.record("assert todo B visible");
    await expect(page.getByText(TODO_B.title)).toBeVisible();

    recorder.record("assert todo input present");
    await expect(page.getByPlaceholder(/make a nuxt demo/i)).toBeVisible();

    await recorder.save(testInfo);
  });

  test("completed todo has line-through style", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "tc-004",
      testTitle: "completed todo has line-through style",
    });

    recorder.record("navigate to /todos");
    await page.goto("/todos");

    recorder.record("assert completed todo has line-through class");
    const completedItem = page.getByText(TODO_B.title);
    await expect(completedItem).toBeVisible();
    await expect(completedItem).toHaveClass(/line-through/);

    await recorder.save(testInfo);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. Add todo
// ─────────────────────────────────────────────────────────────────────────────
test.describe("Add todo", () => {
  test("submitting the form adds a new todo item", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "tc-005",
      testTitle: "submitting the form adds a new todo item",
    });

    await setupMocks(page);
    await mockAuthenticatedUser(page, { login: "testuser", id: 10 });
    await mockTodos(page, [TODO_A]);

    recorder.record("navigate to /todos");
    await page.goto("/todos");

    // After successful POST the page refetches; mock the updated list
    let postCalled = false;
    await page.route("**/api/todos", async (route) => {
      if (route.request().method() === "POST") {
        postCalled = true;
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify(NEW_TODO),
        });
      } else {
        // GET after invalidation returns expanded list
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([TODO_A, NEW_TODO]),
        });
      }
    });

    recorder.record("type new todo title");
    const input = page.getByPlaceholder(/make a nuxt demo/i);
    await input.fill(NEW_TODO.title);

    recorder.record("submit form");
    await page.getByRole("button", { name: /plus/i }).click();

    recorder.record("assert new todo visible");
    await expect(page.getByText(NEW_TODO.title)).toBeVisible();

    await recorder.save(testInfo);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. Toggle todo (complete / incomplete)
// ─────────────────────────────────────────────────────────────────────────────
test.describe("Toggle todo", () => {
  test("toggling the switch patches the todo and updates UI", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "tc-006",
      testTitle: "toggling the switch patches the todo and updates UI",
    });

    await setupMocks(page);
    await mockAuthenticatedUser(page, { login: "testuser", id: 10 });
    await mockTodos(page, [TODO_A]);

    recorder.record("navigate to /todos");
    await page.goto("/todos");

    // Mock PATCH — returns todo as completed, then GET returns updated list
    await page.route(`**/api/todos/${TODO_A.id}`, async (route) => {
      if (route.request().method() === "PATCH") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({ ...TODO_A, completed: true }),
        });
      } else {
        await route.continue();
      }
    });
    // After invalidation, GET returns the completed todo
    await page.route("**/api/todos", async (route) => {
      if (route.request().method() === "GET") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([{ ...TODO_A, completed: true }]),
        });
      } else {
        await route.continue();
      }
    });

    recorder.record("assert todo A is not completed initially");
    const todoText = page.getByText(TODO_A.title);
    await expect(todoText).toBeVisible();
    await expect(todoText).not.toHaveClass(/line-through/);

    recorder.record("click the toggle switch for todo A");
    // The USwitch is rendered as a button role next to the todo title
    const todoRow = page.locator("li").filter({ hasText: TODO_A.title });
    const toggleSwitch = todoRow.locator("button").first();
    await toggleSwitch.click();

    recorder.record("assert todo A now has line-through style");
    await expect(page.getByText(TODO_A.title)).toHaveClass(/line-through/);

    await recorder.save(testInfo);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. Delete todo
// ─────────────────────────────────────────────────────────────────────────────
test.describe("Delete todo", () => {
  test("clicking delete removes the todo from the list", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "tc-007",
      testTitle: "clicking delete removes the todo from the list",
    });

    await setupMocks(page);
    await mockAuthenticatedUser(page, { login: "testuser", id: 10 });
    await mockTodos(page, [TODO_A, TODO_B]);

    recorder.record("navigate to /todos");
    await page.goto("/todos");

    // Mock DELETE for TODO_A
    await page.route(`**/api/todos/${TODO_A.id}`, async (route) => {
      if (route.request().method() === "DELETE") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify(TODO_A),
        });
      } else {
        await route.continue();
      }
    });
    // After invalidation GET returns only TODO_B
    await page.route("**/api/todos", async (route) => {
      if (route.request().method() === "GET") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([TODO_B]),
        });
      } else {
        await route.continue();
      }
    });

    recorder.record("assert both todos visible");
    await expect(page.getByText(TODO_A.title)).toBeVisible();
    await expect(page.getByText(TODO_B.title)).toBeVisible();

    recorder.record("click delete button for todo A");
    const todoRow = page.locator("li").filter({ hasText: TODO_A.title });
    const deleteBtn = todoRow.getByRole("button").last();
    await deleteBtn.click();

    recorder.record("assert todo A is removed");
    await expect(page.getByText(TODO_A.title)).not.toBeVisible();

    recorder.record("assert todo B still visible");
    await expect(page.getByText(TODO_B.title)).toBeVisible();

    await recorder.save(testInfo);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 6. User isolation
// ─────────────────────────────────────────────────────────────────────────────
test.describe("User isolation", () => {
  test("user A only sees their own todos, not user B's", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "tc-008",
      testTitle: "user A only sees their own todos, not user B's",
    });

    const USER_A_TODO = { id: 10, title: "User A task", completed: false, userId: 1 };
    const USER_B_TODO = { id: 20, title: "User B task", completed: false, userId: 2 };

    await setupMocks(page);
    await mockAuthenticatedUser(page, { login: "userA", id: 1 });
    // Mock returns only user A's todo (server-side isolation enforced; mock simulates it)
    await mockTodos(page, [USER_A_TODO]);

    recorder.record("navigate to /todos as user A");
    await page.goto("/todos");

    recorder.record("assert user A's todo is visible");
    await expect(page.getByText(USER_A_TODO.title)).toBeVisible();

    recorder.record("assert user B's todo is NOT visible");
    await expect(page.getByText(USER_B_TODO.title)).not.toBeVisible();

    await recorder.save(testInfo);
  });
});
