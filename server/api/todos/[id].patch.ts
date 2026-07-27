import { z } from 'zod'
import { db, schema } from 'hub:db'
import { and, eq } from 'drizzle-orm'

const ParamsSchema = z.object({
  id: z.coerce.number().int()
})

const BodySchema = z.object({
  completed: z.boolean()
})

export default eventHandler(async (event) => {
  const { id } = await getValidatedRouterParams(event, ParamsSchema.parse)
  const { completed } = await readValidatedBody(event, BodySchema.parse)
  const { user } = await requireUserSession(event)

  const mocked = readCodevalidMockTodos(event)
  if (mocked) {
    const idx = mocked.findIndex(
      (todo) => Number(todo.id) === id && (!todo.userId || Number(todo.userId) === Number(user.id)),
    )
    if (idx < 0) {
      throw createError({ statusCode: 404, message: 'Todo not found' })
    }
    const updated = {
      ...mocked[idx],
      completed: completed ? 1 : 0,
    }
    const next = [...mocked]
    next[idx] = updated
    writeCodevalidMockTodos(event, next)
    return updated
  }

  // Update todo for the current user
  const updatedTodos = await db.update(schema.todos).set({
    completed: completed ? 1 : 0
  }).where(and(
    eq(schema.todos.id, id),
    eq(schema.todos.userId, user.id)
  )).returning()

  const todo = updatedTodos[0]
  if (!todo) {
    throw createError({
      statusCode: 404,
      message: 'Todo not found'
    })
  }
  return todo
})
