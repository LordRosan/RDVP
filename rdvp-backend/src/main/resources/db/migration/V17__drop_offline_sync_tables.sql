-- V17: Drop offline sync tables (offline mode removed from v1 online-only architecture)
DROP TABLE IF EXISTS offline_sync_records CASCADE;
DROP TABLE IF EXISTS offline_sync_batches CASCADE;
