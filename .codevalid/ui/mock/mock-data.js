export const optimisticTodosFixtures = {
  authenticatedUser: {
    id: 101,
    login: "alice",
  },
  authenticatedTodos: [
    {
      id: 1,
      title: "Pay rent",
      completed: 0,
      userId: 101,
      createdAt: "2026-07-26T10:00:00.000Z",
    },
    {
      id: 2,
      title: "Buy groceries",
      completed: 1,
      userId: 101,
      createdAt: "2026-07-26T11:00:00.000Z",
    },
  ],
};
