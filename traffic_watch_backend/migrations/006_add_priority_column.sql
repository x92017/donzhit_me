-- Add priority column for approved reports (higher number = higher priority)
-- Default to 100 for existing approved reports
ALTER TABLE reports ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT NULL;

-- Set default priority for existing approved reports
UPDATE reports SET priority = 100 WHERE status = 'reviewed_pass' AND priority IS NULL;

-- Create index for sorting by priority (DESC) and date (DESC)
CREATE INDEX IF NOT EXISTS idx_reports_priority_date ON reports(priority DESC, created_at DESC) WHERE status = 'reviewed_pass';
