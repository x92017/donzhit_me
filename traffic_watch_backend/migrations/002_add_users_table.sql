-- migrations/002_add_users_table.sql
-- Users table for JWT-based authentication with role-based access control

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(255) PRIMARY KEY,           -- Google subject ID
    email VARCHAR(255) NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL DEFAULT 'contributor'
        CHECK (role IN ('viewer', 'contributor', 'admin')),
    jwt_refresh_token VARCHAR(64),         -- For token revocation
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Auto-update trigger (reuses function from 001_initial_schema.sql)
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
