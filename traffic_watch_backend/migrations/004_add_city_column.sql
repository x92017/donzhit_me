-- Migration: Add city column to reports table
-- This allows users to optionally specify a city when creating reports

ALTER TABLE reports ADD COLUMN IF NOT EXISTS city VARCHAR(100);

-- Create index for efficient city-based queries
CREATE INDEX IF NOT EXISTS idx_reports_city ON reports(city);
