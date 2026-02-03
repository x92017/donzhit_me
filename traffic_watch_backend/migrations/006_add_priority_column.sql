-- Add priority column for approved reports (1=highest priority, 5=lowest)
-- Default to 3 (medium priority) for existing approved reports
ALTER TABLE reports ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT NULL;

-- Set default priority for existing approved reports
UPDATE reports SET priority = 3 WHERE status = 'reviewed_pass' AND priority IS NULL;

-- Create index for sorting by priority and date
CREATE INDEX IF NOT EXISTS idx_reports_priority_date ON reports(priority, created_at DESC) WHERE status = 'reviewed_pass';
