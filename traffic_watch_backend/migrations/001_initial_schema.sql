-- migrations/001_initial_schema.sql
-- Initial database schema for DonzHit.me Traffic Watch Backend

-- Reports table stores traffic incident reports
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY,
    user_id TEXT NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    date_time TIMESTAMP WITH TIME ZONE NOT NULL,
    road_usage VARCHAR(50) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    injuries TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Media files table stores references to uploaded media
CREATE TABLE IF NOT EXISTS media_files (
    id TEXT PRIMARY KEY,  -- TEXT to support both UUIDs and YouTube video IDs
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    size BIGINT NOT NULL,
    url TEXT NOT NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_user_status ON reports(user_id, status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_files_report_id ON media_files(report_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-update updated_at on reports
DROP TRIGGER IF EXISTS update_reports_updated_at ON reports;
CREATE TRIGGER update_reports_updated_at
    BEFORE UPDATE ON reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
