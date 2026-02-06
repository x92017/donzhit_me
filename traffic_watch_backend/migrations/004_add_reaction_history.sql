-- Add modified_at and history_reaction_type columns to report_reactions table
ALTER TABLE report_reactions ADD COLUMN IF NOT EXISTS modified_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE report_reactions ADD COLUMN IF NOT EXISTS history_reaction_type TEXT DEFAULT '';

-- Clean up duplicate reactions: keep only the most recent reaction per user per report
-- Step 1: For users with multiple reactions on the same report, update the most recent one
-- to include the older reaction types in history_reaction_type
UPDATE report_reactions r
SET history_reaction_type = (
    SELECT STRING_AGG(reaction_type, ',' ORDER BY created_at)
    FROM report_reactions r2
    WHERE r2.report_id = r.report_id
      AND r2.user_id = r.user_id
      AND r2.id != r.id
),
modified_at = NOW()
WHERE r.id IN (
    SELECT DISTINCT ON (report_id, user_id) id
    FROM report_reactions
    ORDER BY report_id, user_id, created_at DESC
)
AND EXISTS (
    SELECT 1 FROM report_reactions r3
    WHERE r3.report_id = r.report_id
      AND r3.user_id = r.user_id
      AND r3.id != r.id
);

-- Step 2: Delete all but the most recent reaction per user per report
DELETE FROM report_reactions
WHERE id NOT IN (
    SELECT DISTINCT ON (report_id, user_id) id
    FROM report_reactions
    ORDER BY report_id, user_id, created_at DESC
);

-- Step 3: Drop the existing constraint if it exists
ALTER TABLE report_reactions DROP CONSTRAINT IF EXISTS report_reactions_report_id_user_id_reaction_type_key;

-- Step 4: Create new unique constraint on just report_id and user_id
ALTER TABLE report_reactions ADD CONSTRAINT report_reactions_report_id_user_id_key UNIQUE (report_id, user_id);

-- Step 5: Create index on modified_at for potential queries
CREATE INDEX IF NOT EXISTS idx_report_reactions_modified_at ON report_reactions(modified_at);
