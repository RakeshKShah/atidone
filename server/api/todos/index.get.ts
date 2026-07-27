import { db, schema } from 'hub:db'
import { eq } from 'drizzle-orm'

export default eventHandler(async (event) => {
  const { user } = await requireUserSession(event)

  const mocked = readCodevalidMockTodos(event)
  if (mocked) {
    return mocked.filter((todo) => !todo?.userId || Number(todo.userId) === Number(user.id))
  }

  // List todos for the current user
  const todos = await db.select().from(schema.todos).where(eq(schema.todos.userId, user.id))

  return todos
})
