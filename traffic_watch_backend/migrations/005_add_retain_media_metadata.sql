-- Add retain_media_metadata column to reports table
-- When false, GPS and date metadata should be stripped from media files
ALTER TABLE reports ADD COLUMN IF NOT EXISTS retain_media_metadata BOOLEAN DEFAULT true;
