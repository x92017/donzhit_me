-- Migration: Convert road_usage and event_type columns from VARCHAR to TEXT[]
-- This allows multiple selections for each field

-- Convert road_usage to array (migrate existing data)
ALTER TABLE reports
  ALTER COLUMN road_usage TYPE TEXT[]
  USING ARRAY[road_usage];

-- Convert event_type to array (migrate existing data)
ALTER TABLE reports
  ALTER COLUMN event_type TYPE TEXT[]
  USING ARRAY[event_type];

-- Create GIN indexes for efficient array queries
CREATE INDEX IF NOT EXISTS idx_reports_road_usage ON reports USING GIN (road_usage);
CREATE INDEX IF NOT EXISTS idx_reports_event_type ON reports USING GIN (event_type);
