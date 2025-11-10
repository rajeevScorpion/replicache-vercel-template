# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Replicache-powered todo list application built with Next.js, designed for deployment on Vercel with Supabase as the backend. The application demonstrates real-time collaboration, instant UI updates, and offline resilience using Replicache's sync protocol.

## Development Commands

```bash
# Start development server
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Format code
npm run format
```

## Architecture

### Replicache Sync Architecture

The application uses Replicache's client-server synchronization pattern:

- **Client-side**: Mutations run optimistically against local cache for instant UI feedback
- **Server-side**: Same mutators re-run authoritatively against the database for conflict resolution
- **Sync Protocol**: Replicache automatically handles synchronization between client and server

### Key Components

**Core Replicache Files:**
- `src/mutators.ts` - Defines mutation functions that run on both client and server
- `src/todo.ts` - Todo domain types and data access helpers
- `src/app.tsx` - Main React component with Replicache integration
- `pages/api/replicache/[op].ts` - Server-side Replicache API endpoint

**Pages Structure:**
- `pages/index.tsx` - Entry point that creates new todo lists and redirects
- `pages/list/[id].tsx` - Individual todo list pages with Replicache integration

**React Components:**
- `src/components/` - Standard React UI components (no Replicache-specific code)

### Data Flow

1. **Create List**: `pages/index.tsx` generates a unique list ID and creates a space server-side
2. **Load List**: `pages/list/[id].tsx` loads the Replicache instance for a specific space
3. **Mutations**: UI interactions call mutators (`rep.mutate.*`) which:
   - Run immediately on client (optimistic)
   - Queue for server synchronization
   - Re-run on server for conflict resolution
4. **Subscription**: `useSubscribe` hook automatically updates UI when data changes

### Replicache Concepts

**Spaces**: Each todo list gets its own isolated data space identified by a unique ID
**Mutators**: Functions that modify data, defined once and used on both client and server
**Optimistic Updates**: All changes appear instantly, then sync with server in background
**Conflict Resolution**: Server-side mutator execution takes precedence over client-side changes

## Dependencies

### Replicache Stack
- `replicache` - Core Replicache library
- `replicache-nextjs` - Next.js integration helpers
- `replicache-react` - React hooks for Replicache

### Other Key Dependencies
- `next` - React framework
- `react` / `react-dom` - React library
- `classnames` - CSS class utility
- `todomvc-app-css` - TodoMVC styling
- `nanoid` - Unique ID generation (imported but not in package.json)

## Development Notes

- The project is forked from `rocicorp/replicache-todo` - most changes happen upstream
- Mutators are the single source of truth for data modifications
- Components are kept completely separate from Replicache logic
- Server-side mutators are automatically called via `/api/replicache/[op]` endpoint
- Each todo list is isolated in its own Replicache space
- The app automatically handles missing spaces by redirecting to create new ones

## Code Style

- Uses Prettier with specific configuration (see package.json)
- ESLint is configured but ignored during builds
- TypeScript is used throughout the codebase