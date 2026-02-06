-- Add reviewed_by column to track which admins have reviewed/updated the report status
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reviewed_by TEXT DEFAULT '';

-- Create index for potential queries by reviewer
CREATE INDEX IF NOT EXISTS idx_reports_reviewed_by ON reports(reviewed_by);
