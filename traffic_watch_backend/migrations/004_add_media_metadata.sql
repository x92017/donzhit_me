-- Add metadata column to media_files table for storing EXIF and other file metadata
ALTER TABLE media_files ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Create index for metadata queries (optional, for future filtering)
CREATE INDEX IF NOT EXISTS idx_media_files_metadata ON media_files USING GIN (metadata);
