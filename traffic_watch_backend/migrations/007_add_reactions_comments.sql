-- Add reactions table for report likes/dislikes
CREATE TABLE IF NOT EXISTS report_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    reaction_type VARCHAR(50) NOT NULL, -- 'thumbs_up', 'thumbs_down', 'angry_car', 'angry_pedestrian', 'angry_bicycle'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(report_id, user_id, reaction_type) -- One reaction type per user per report
);

-- Add comments table for report comments
CREATE TABLE IF NOT EXISTS report_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_report_reactions_report_id ON report_reactions(report_id);
CREATE INDEX IF NOT EXISTS idx_report_reactions_user_id ON report_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_report_comments_report_id ON report_comments(report_id);
CREATE INDEX IF NOT EXISTS idx_report_comments_created_at ON report_comments(created_at DESC);
