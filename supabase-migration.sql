-- Replicache Migration for Supabase
-- Run this in your Supabase SQL Editor

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

-- Row Level Security (RLS) policies
ALTER TABLE replicache_space ENABLE ROW LEVEL SECURITY;
ALTER TABLE replicache_client ENABLE ROW LEVEL SECURITY;
ALTER TABLE replicache_client_group ENABLE ROW LEVEL SECURITY;

-- Allow all operations for development (adjust for production)
CREATE POLICY "Enable all operations on replicache_space" ON replicache_space
  FOR ALL USING (true);
CREATE POLICY "Enable all operations on replicache_client" ON replicache_client
  FOR ALL USING (true);
CREATE POLICY "Enable all operations on replicache_client_group" ON replicache_client_group
  FOR ALL USING (true);