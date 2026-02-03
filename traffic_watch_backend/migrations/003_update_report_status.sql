-- Migration: Update report status workflow
-- Add review_reason column for rejection feedback
ALTER TABLE reports ADD COLUMN IF NOT EXISTS review_reason TEXT;

-- Migrate existing 'active' reports to 'submitted'
UPDATE reports SET status = 'submitted' WHERE status = 'active';

-- Add index for approved reports query (public feed)
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_status_created ON reports(status, created_at DESC);
