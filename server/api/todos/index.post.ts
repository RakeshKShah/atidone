import { z } from 'zod'
import { db, schema } from 'hub:db'

const BodySchema = z.object({
  title: z.string().min(1).max(100)
})

export default eventHandler(async (event) => {
  const { title } = await readValidatedBody(event, body => BodySchema.parse(body))
  const { user } = await requireUserSession(event)

  const mocked = readCodevalidMockTodos(event)
  if (mocked) {
    const created = {
      id: Date.now(),
      title,
      completed: 0,
      userId: user.id,
      createdAt: new Date().toISOString(),
    }
    writeCodevalidMockTodos(event, [...mocked, created])
    return created
  }

  // Insert todo for the current user
  const todos = await db.insert(schema.todos).values({
    userId: user.id,
    title,
    createdAt: new Date()
  }).returning()

  return todos[0]
})
