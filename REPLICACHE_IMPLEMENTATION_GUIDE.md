# Replicache Implementation Guide for Next.js + Supabase

This comprehensive guide covers everything you need to implement Replicache in a Next.js web application with Supabase as the backend.

## Overview

Replicache is a JavaScript library that enables real-time collaboration, instant UI updates, and offline resilience in web applications. It uses a client-server synchronization pattern with optimistic updates.

## Architecture Concepts

### 1. **Spaces**
- Each isolated dataset is called a "space"
- Multiple spaces can exist in a single application
- Example: Each document or chat room gets its own space

### 2. **Mutators**
- Functions that modify data
- Defined once and used on both client and server
- Run optimistically on client, then authoritatively on server
- Handle conflict resolution automatically

### 3. **Sync Protocol**
- Client sends mutations to server
- Server re-runs mutations for validation
- Server sends back authoritative state
- Client reconciles differences

## Step-by-Step Implementation

### Phase 1: Project Setup

#### 1.1 Install Dependencies

```bash
# Core Replicache packages
npm install replicache replicache-react replicache-nextjs

# Additional dependencies
npm install nanoid # For generating unique IDs
npm install @types/nanoid # TypeScript types
```

#### 1.2 Environment Variables

Create `.env.local`:
```env
# Replicache License Key (get from https://replicache.dev/license)
NEXT_PUBLIC_REPLICACHE_LICENSE_KEY=your_license_key_here

# Supabase Database URL
DATABASE_URL=postgresql://postgres:[password]@db.[project-ref].supabase.co:5432/postgres?sslmode=require
```

Create `.env.example` as template:
```env
NEXT_PUBLIC_REPLICACHE_LICENSE_KEY=your_replicache_license_key_here
DATABASE_URL=postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres?sslmode=require
```

### Phase 2: Database Setup

#### 2.1 Create Replicache Tables

Run this SQL in your Supabase SQL Editor:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create replicache tables
CREATE TABLE IF NOT EXISTS replicache_space (
  id TEXT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS replicache_client (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES replicache_space(id) ON DELETE CASCADE,
  client_group_id TEXT NOT NULL,
  last_mutation_id BIGINT NOT NULL,
  version BIGINT NOT NULL,
  UNIQUE (space_id, client_group_id)
);

CREATE TABLE IF NOT EXISTS replicache_client_group (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES replicache_space(id) ON DELETE CASCADE,
  cvr JSONB NOT NULL,
  UNIQUE (space_id, id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_replicache_client_space_id ON replicache_client(space_id);
CREATE INDEX IF NOT EXISTS idx_replicache_client_group_space_id ON replicache_client_group(space_id);

-- Enable Row Level Security
ALTER TABLE replicache_space ENABLE ROW LEVEL SECURITY;
ALTER TABLE replicache_client ENABLE ROW LEVEL SECURITY;
ALTER TABLE replicache_client_group ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (adjust for production)
CREATE POLICY "Enable all operations on replicache_space" ON replicache_space
  FOR ALL USING (true);
CREATE POLICY "Enable all operations on replicache_client" ON replicache_client
  FOR ALL USING (true);
CREATE POLICY "Enable all operations on replicache_client_group" ON replicache_client_group
  FOR ALL USING (true);
```

#### 2.2 Application Tables

Create your application-specific tables. For a todo app:

```sql
-- Todo items table
CREATE TABLE IF NOT EXISTS todo_items (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES replicache_space(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT false,
  sort_order INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for querying todos by space
CREATE INDEX IF NOT EXISTS idx_todo_items_space_id ON todo_items(space_id);
```

### Phase 3: Define Data Types and Mutators

#### 3.1 Create Type Definitions

```typescript
// src/types/todo.ts
import { ReadTransaction } from "replicache";

export interface Todo {
  id: string;
  text: string;
  completed: boolean;
  sort: number;
}

export interface TodoUpdate {
  id: string;
  text?: string;
  completed?: boolean;
  sort?: number;
}

// Helper function to query todos
export async function listTodos(tx: ReadTransaction) {
  return (await tx.scan().values().toArray()) as Todo[];
}
```

#### 3.2 Create Mutators

```typescript
// src/mutators.ts
import { WriteTransaction } from "replicache";
import { Todo, TodoUpdate, listTodos } from "./types/todo";

export type M = typeof mutators;

export const mutators = {
  // Create a new todo
  createTodo: async (tx: WriteTransaction, todo: Omit<Todo, "sort">) => {
    const todos = await listTodos(tx);
    todos.sort((t1, t2) => t1.sort - t2.sort);
    const maxSort = todos.pop()?.sort ?? 0;
    await tx.put(todo.id, { ...todo, sort: maxSort + 1 });
  },

  // Update an existing todo
  updateTodo: async (tx: WriteTransaction, update: TodoUpdate) => {
    const prev = (await tx.get(update.id)) as Todo;
    const next = { ...prev, ...update };
    await tx.put(next.id, next);
  },

  // Delete a todo
  deleteTodo: async (tx: WriteTransaction, id: string) => {
    await tx.del(id);
  },
};
```

### Phase 4: Create API Endpoint

#### 4.1 Replicache API Route

```typescript
// pages/api/replicache/[op].ts
import { NextApiRequest, NextApiResponse } from "next";
import { handleRequest } from "replicache-nextjs/lib/backend";
import { mutators } from "../../../src/mutators";

export default async (req: NextApiRequest, res: NextApiResponse) => {
  await handleRequest(req, res, mutators);
};
```

### Phase 5: Frontend Implementation

#### 5.1 Initialize Replicache

```typescript
// pages/list/[id].tsx
import { useReplicache } from "replicache-nextjs/lib/frontend";
import { mutators } from "../../src/mutators";

export default function TodoList({ listID }: { listID: string }) {
  const rep = useReplicache(listID, mutators);

  if (!rep) {
    return <div>Loading...</div>;
  }

  return <TodoApp rep={rep} />;
}
```

#### 5.2 Create React Component

```typescript
// src/app.tsx
import { useSubscribe } from "replicache-react";
import { nanoid } from "nanoid";
import { listTodos, TodoUpdate } from "./types/todo";

const TodoApp = ({ rep }) => {
  // Subscribe to all todos
  const todos = useSubscribe(rep, listTodos, [], [rep]);
  todos.sort((a, b) => a.sort - b.sort);

  // Event handlers
  const handleNewTodo = (text: string) => {
    rep.mutate.createTodo({
      id: nanoid(),
      text,
      completed: false,
    });
  };

  const handleUpdateTodo = (update: TodoUpdate) => {
    rep.mutate.updateTodo(update);
  };

  const handleDeleteTodo = (id: string) => {
    rep.mutate.deleteTodo(id);
  };

  // Render your UI
  return (
    <div>
      {/* Your todo list UI */}
    </div>
  );
};
```

### Phase 6: Create and Manage Spaces

#### 6.1 Create New Space

```typescript
// pages/index.ts
import { nanoid } from "nanoid";
import { createSpace } from "replicache-nextjs/lib/backend";

export const getServerSideProps: GetServerSideProps = async () => {
  const spaceID = nanoid(6);
  await createSpace(spaceID);

  return {
    redirect: {
      destination: `/list/${spaceID}`,
      permanent: false,
    },
  };
};
```

#### 6.2 Check if Space Exists

```typescript
// pages/list/[id].tsx
import { spaceExists } from "replicache-nextjs/lib/backend";

export const getServerSideProps: GetServerSideProps = async (context) => {
  const { id: spaceID } = context.params as { id: string };

  if (!(await spaceExists(spaceID))) {
    return {
      redirect: {
        destination: `/`,
        permanent: false,
      },
    };
  }

  return { props: { spaceID } };
};
```

## Best Practices

### 1. **Data Modeling**
- Keep mutators simple and focused
- Always include space_id in your data relationships
- Use consistent naming for IDs (space_id, client_id, etc.)

### 2. **Performance**
- Use subscriptions efficiently - only subscribe to data you need
- Implement pagination for large datasets
- Consider using React.memo for expensive components

### 3. **Error Handling**
- Always validate input in mutators
- Handle network errors gracefully
- Provide feedback for failed operations

### 4. **Security**
- Implement proper RLS policies in Supabase
- Validate all inputs on the server
- Use environment variables for sensitive data

### 5. **Testing**
- Test mutators independently
- Test conflict resolution scenarios
- Test offline/online behavior

## Common Patterns

### 1. **Bulk Operations**
```typescript
const bulkUpdate = async (tx: WriteTransaction, updates: TodoUpdate[]) => {
  for (const update of updates) {
    const prev = await tx.get(update.id);
    const next = { ...prev, ...update };
    await tx.put(update.id, next);
  }
};
```

### 2. **Conditional Updates**
```typescript
const toggleComplete = async (tx: WriteTransaction, id: string) => {
  const todo = (await tx.get(id)) as Todo;
  await tx.put(id, { ...todo, completed: !todo.completed });
};
```

### 3. **Sorting and Ordering**
```typescript
const reorderTodos = async (tx: WriteTransaction, fromIndex: number, toIndex: number) => {
  const todos = await listTodos(tx);
  todos.sort((a, b) => a.sort - b.sort);

  const [moved] = todos.splice(fromIndex, 1);
  todos.splice(toIndex, 0, moved);

  // Update sort values
  for (let i = 0; i < todos.length; i++) {
    await tx.put(todos[i].id, { ...todos[i], sort: i * 10 });
  }
};
```

## Deployment

### Vercel Deployment

1. Push code to GitHub
2. Connect repository to Vercel
3. Configure environment variables in Vercel dashboard:
   - `NEXT_PUBLIC_REPLICACHE_LICENSE_KEY`
   - `DATABASE_URL`
4. Deploy

### Environment Variables Checklist

For production:
- [ ] Replicache license key
- [ ] Supabase database URL with SSL
- [ ] Any other API keys or secrets

## Troubleshooting

### Common Issues

1. **DNS Resolution Errors**
   - Ensure database URL includes `?sslmode=require`
   - Check if Supabase project is active
   - Verify network connectivity

2. **CORS Issues**
   - Ensure API routes handle CORS properly
   - Check Vercel domain is whitelisted in Supabase

3. **Sync Not Working**
   - Verify mutators are identical on client and server
   - Check browser console for errors
   - Ensure database tables exist

4. **Performance Issues**
   - Implement proper indexing
   - Use pagination for large datasets
   - Optimize subscriptions

## Migration from Existing App

1. **Install Replicache dependencies**
2. **Create mutators from existing API endpoints**
3. **Replace state management with Replicache**
4. **Update UI to use Replicache subscriptions**
5. **Implement optimistic updates**
6. **Add offline support**

## Example Project Structure

```
your-app/
├── src/
│   ├── components/          # React components
│   ├── mutators.ts         # Replicache mutators
│   ├── types/              # TypeScript types
│   │   └── todo.ts
│   ├── app.tsx            # Main app component
│   └── utils/             # Helper functions
├── pages/
│   ├── api/
│   │   └── replicache/
│   │       └── [op].ts    # Replicache API endpoint
│   ├── index.tsx          # Landing/create space
│   └── list/
│       └── [id].tsx       # Individual space view
├── .env.local             # Local environment
├── .env.example           # Environment template
└── package.json
```

## Conclusion

Replicache provides powerful capabilities for building real-time collaborative applications with offline support. The key is understanding the sync protocol and properly structuring your mutators and data model.

Remember to:
- Start simple and add complexity gradually
- Test thoroughly, especially conflict resolution
- Monitor performance in production
- Keep mutators pure and predictable

This guide provides everything you need to successfully implement Replicache in your Next.js + Supabase applications!