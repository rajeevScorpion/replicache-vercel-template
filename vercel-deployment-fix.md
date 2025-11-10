# Fix for Vercel Deployment Error

## Issue
The error shows Vercel trying to connect to Supabase via IPv6 and failing. We need to force IPv4 connection.

## Solution
Update your Vercel environment variables to use the DATABASE_URL format instead of the separate Supabase variables.

### Replace these environment variables in Vercel:

**Remove:**
- NEXT_PUBLIC_SUPABASE_URL
- NEXT_PUBLIC_SUPABASE_ANON_KEY
- SUPABASE_DATABASE_PASSWORD

**Add this single variable:**
```
DATABASE_URL=postgresql://postgres:Anari@420@db.mtvlnizkfvajkbanlzzp.supabase.co:5432/postgres?sslmode=require&connect_timeout=10
```

### Alternative: Use Connection Pooling
If the above doesn't work, try Supabase's connection pooling:

```
DATABASE_URL=postgresql://postgres:Anari@420@db.mtvlnizkfvajkbanlzzp.supabase.co:6543/postgres?sslmode=require&connect_timeout=10&pool_timeout=10
```

Note the port change from 5432 to 6543 for the pooler.

### Steps:
1. Go to your Vercel project dashboard
2. Go to Settings > Environment Variables
3. Remove the three Supabase variables
4. Add the DATABASE_URL
5. Redeploy the application