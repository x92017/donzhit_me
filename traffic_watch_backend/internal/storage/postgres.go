package storage

import (
	"context"
	"errors"
	"fmt"
	"net"
	"time"

	"cloud.google.com/go/cloudsqlconn"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"donzhit_me_backend/internal/models"
)

// PostgresClient wraps the pgx connection pool
type PostgresClient struct {
	pool   *pgxpool.Pool
	dialer *cloudsqlconn.Dialer
}

// NewPostgresClient creates a new PostgreSQL client using Cloud SQL connector
func NewPostgresClient(ctx context.Context, instanceConnName, dbUser, dbPassword, dbName string) (*PostgresClient, error) {
	dialer, err := cloudsqlconn.NewDialer(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create Cloud SQL dialer: %w", err)
	}

	dsn := fmt.Sprintf("user=%s password=%s dbname=%s sslmode=disable", dbUser, dbPassword, dbName)

	config, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		dialer.Close()
		return nil, fmt.Errorf("failed to parse config: %w", err)
	}

	// Configure connection using Cloud SQL connector
	config.ConnConfig.DialFunc = func(ctx context.Context, network, addr string) (net.Conn, error) {
		return dialer.Dial(ctx, instanceConnName)
	}

	// Connection pool settings
	config.MaxConns = 10
	config.MinConns = 1
	config.MaxConnLifetime = time.Hour
	config.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		dialer.Close()
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	// Verify connection
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		dialer.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return &PostgresClient{
		pool:   pool,
		dialer: dialer,
	}, nil
}

// NewPostgresClientFromConnString creates a PostgreSQL client from a connection string (for local dev)
func NewPostgresClientFromConnString(ctx context.Context, connString string) (*PostgresClient, error) {
	config, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("failed to parse connection string: %w", err)
	}

	config.MaxConns = 10
	config.MinConns = 1
	config.MaxConnLifetime = time.Hour
	config.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return &PostgresClient{
		pool:   pool,
		dialer: nil,
	}, nil
}

// Close closes the PostgreSQL client
func (p *PostgresClient) Close() error {
	p.pool.Close()
	if p.dialer != nil {
		return p.dialer.Close()
	}
	return nil
}

// CreateReport creates a new report in PostgreSQL
func (p *PostgresClient) CreateReport(ctx context.Context, report *models.TrafficReport) error {
	if report.ID == "" {
		return errors.New("report ID is required")
	}

	report.CreatedAt = time.Now()
	report.UpdatedAt = time.Now()
	report.Status = models.StatusSubmitted

	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Insert report
	_, err = tx.Exec(ctx, `
		INSERT INTO reports (id, user_id, title, description, date_time, road_usage, event_type, state, city, injuries, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
	`, report.ID, report.UserID, report.Title, report.Description, report.DateTime,
		report.RoadUsage, report.EventType, report.State, report.City, report.Injuries,
		report.Status, report.CreatedAt, report.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert report: %w", err)
	}

	// Insert media files
	for _, mf := range report.MediaFiles {
		_, err = tx.Exec(ctx, `
			INSERT INTO media_files (id, report_id, file_name, content_type, size, url, uploaded_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
		`, mf.ID, report.ID, mf.FileName, mf.ContentType, mf.Size, mf.URL, mf.UploadedAt)
		if err != nil {
			return fmt.Errorf("failed to insert media file: %w", err)
		}
	}

	return tx.Commit(ctx)
}

// GetReport retrieves a report by ID
func (p *PostgresClient) GetReport(ctx context.Context, reportID string) (*models.TrafficReport, error) {
	report := &models.TrafficReport{}

	err := p.pool.QueryRow(ctx, `
		SELECT id, user_id, title, description, date_time, road_usage, event_type, state, COALESCE(city, ''), injuries, status, created_at, updated_at
		FROM reports WHERE id = $1
	`, reportID).Scan(
		&report.ID, &report.UserID, &report.Title, &report.Description, &report.DateTime,
		&report.RoadUsage, &report.EventType, &report.State, &report.City, &report.Injuries,
		&report.Status, &report.CreatedAt, &report.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("report not found")
		}
		return nil, fmt.Errorf("failed to get report: %w", err)
	}

	// Get media files
	rows, err := p.pool.Query(ctx, `
		SELECT id, file_name, content_type, size, url, uploaded_at
		FROM media_files WHERE report_id = $1
	`, reportID)
	if err != nil {
		return nil, fmt.Errorf("failed to get media files: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var mf models.MediaFile
		if err := rows.Scan(&mf.ID, &mf.FileName, &mf.ContentType, &mf.Size, &mf.URL, &mf.UploadedAt); err != nil {
			return nil, fmt.Errorf("failed to scan media file: %w", err)
		}
		report.MediaFiles = append(report.MediaFiles, mf)
	}

	if report.MediaFiles == nil {
		report.MediaFiles = []models.MediaFile{}
	}

	return report, nil
}

// GetReportByIDAndUser retrieves a report by ID and verifies user ownership
func (p *PostgresClient) GetReportByIDAndUser(ctx context.Context, reportID, userID string) (*models.TrafficReport, error) {
	report, err := p.GetReport(ctx, reportID)
	if err != nil {
		return nil, err
	}

	if report.UserID != userID {
		return nil, errors.New("report not found")
	}

	if report.Status == models.StatusDeleted {
		return nil, errors.New("report not found")
	}

	return report, nil
}

// ListReportsByUser retrieves all non-deleted reports for a user
func (p *PostgresClient) ListReportsByUser(ctx context.Context, userID string) ([]models.TrafficReport, error) {
	rows, err := p.pool.Query(ctx, `
		SELECT id, user_id, title, description, date_time, road_usage, event_type, state, COALESCE(city, ''), injuries, status, created_at, updated_at, COALESCE(review_reason, '')
		FROM reports
		WHERE user_id = $1 AND status != $2
		ORDER BY created_at DESC
	`, userID, models.StatusDeleted)
	if err != nil {
		return nil, fmt.Errorf("failed to list reports: %w", err)
	}
	defer rows.Close()

	var reports []models.TrafficReport
	for rows.Next() {
		var report models.TrafficReport
		if err := rows.Scan(
			&report.ID, &report.UserID, &report.Title, &report.Description, &report.DateTime,
			&report.RoadUsage, &report.EventType, &report.State, &report.City, &report.Injuries,
			&report.Status, &report.CreatedAt, &report.UpdatedAt, &report.ReviewReason,
		); err != nil {
			return nil, fmt.Errorf("failed to scan report: %w", err)
		}
		report.MediaFiles = []models.MediaFile{}
		reports = append(reports, report)
	}

	// Get media files for all reports
	if len(reports) > 0 {
		reportIDs := make([]string, len(reports))
		reportMap := make(map[string]*models.TrafficReport)
		for i := range reports {
			reportIDs[i] = reports[i].ID
			reportMap[reports[i].ID] = &reports[i]
		}

		mediaRows, err := p.pool.Query(ctx, `
			SELECT report_id, id, file_name, content_type, size, url, uploaded_at
			FROM media_files WHERE report_id = ANY($1)
		`, reportIDs)
		if err != nil {
			return nil, fmt.Errorf("failed to get media files: %w", err)
		}
		defer mediaRows.Close()

		for mediaRows.Next() {
			var reportID string
			var mf models.MediaFile
			if err := mediaRows.Scan(&reportID, &mf.ID, &mf.FileName, &mf.ContentType, &mf.Size, &mf.URL, &mf.UploadedAt); err != nil {
				return nil, fmt.Errorf("failed to scan media file: %w", err)
			}
			if r, ok := reportMap[reportID]; ok {
				r.MediaFiles = append(r.MediaFiles, mf)
			}
		}
	}

	if reports == nil {
		reports = []models.TrafficReport{}
	}

	return reports, nil
}

// UpdateReport updates an existing report
func (p *PostgresClient) UpdateReport(ctx context.Context, report *models.TrafficReport) error {
	report.UpdatedAt = time.Now()

	_, err := p.pool.Exec(ctx, `
		UPDATE reports
		SET title = $2, description = $3, date_time = $4, road_usage = $5, event_type = $6,
		    state = $7, city = $8, injuries = $9, status = $10, updated_at = $11
		WHERE id = $1
	`, report.ID, report.Title, report.Description, report.DateTime, report.RoadUsage,
		report.EventType, report.State, report.City, report.Injuries, report.Status, report.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to update report: %w", err)
	}

	return nil
}

// DeleteReport performs a soft delete on a report
func (p *PostgresClient) DeleteReport(ctx context.Context, reportID, userID string) error {
	report, err := p.GetReportByIDAndUser(ctx, reportID, userID)
	if err != nil {
		return err
	}

	report.Status = models.StatusDeleted
	return p.UpdateReport(ctx, report)
}

// AddMediaFileToReport adds a media file reference to a report
func (p *PostgresClient) AddMediaFileToReport(ctx context.Context, reportID string, mediaFile models.MediaFile) error {
	_, err := p.pool.Exec(ctx, `
		INSERT INTO media_files (id, report_id, file_name, content_type, size, url, uploaded_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, mediaFile.ID, reportID, mediaFile.FileName, mediaFile.ContentType, mediaFile.Size, mediaFile.URL, mediaFile.UploadedAt)
	if err != nil {
		return fmt.Errorf("failed to add media file: %w", err)
	}

	// Update report's updated_at
	_, err = p.pool.Exec(ctx, `UPDATE reports SET updated_at = $2 WHERE id = $1`, reportID, time.Now())
	if err != nil {
		return fmt.Errorf("failed to update report timestamp: %w", err)
	}

	return nil
}

// ============================================================================
// Admin Report Methods
// ============================================================================

// ListAllReports retrieves all non-deleted reports (for admin dashboard)
func (p *PostgresClient) ListAllReports(ctx context.Context) ([]models.TrafficReport, error) {
	rows, err := p.pool.Query(ctx, `
		SELECT id, user_id, title, description, date_time, road_usage, event_type, state, COALESCE(city, ''), injuries, status, created_at, updated_at, COALESCE(review_reason, '')
		FROM reports
		WHERE status != $1
		ORDER BY created_at DESC
	`, models.StatusDeleted)
	if err != nil {
		return nil, fmt.Errorf("failed to list all reports: %w", err)
	}
	defer rows.Close()

	return p.scanReportsWithMedia(ctx, rows)
}

// ListReportsAwaitingReview retrieves reports with "submitted" status (for admin review queue)
func (p *PostgresClient) ListReportsAwaitingReview(ctx context.Context) ([]models.TrafficReport, error) {
	rows, err := p.pool.Query(ctx, `
		SELECT id, user_id, title, description, date_time, road_usage, event_type, state, COALESCE(city, ''), injuries, status, created_at, updated_at, COALESCE(review_reason, '')
		FROM reports
		WHERE status = $1
		ORDER BY created_at ASC
	`, models.StatusSubmitted)
	if err != nil {
		return nil, fmt.Errorf("failed to list reports awaiting review: %w", err)
	}
	defer rows.Close()

	return p.scanReportsWithMedia(ctx, rows)
}

// ListApprovedReports retrieves reports with "reviewed_pass" status (for public feed)
func (p *PostgresClient) ListApprovedReports(ctx context.Context) ([]models.TrafficReport, error) {
	rows, err := p.pool.Query(ctx, `
		SELECT id, user_id, title, description, date_time, road_usage, event_type, state, COALESCE(city, ''), injuries, status, created_at, updated_at, COALESCE(review_reason, '')
		FROM reports
		WHERE status = $1
		ORDER BY created_at DESC
	`, models.StatusReviewedPass)
	if err != nil {
		return nil, fmt.Errorf("failed to list approved reports: %w", err)
	}
	defer rows.Close()

	return p.scanReportsWithMedia(ctx, rows)
}

// UpdateReportStatus updates a report's status and optional review reason
func (p *PostgresClient) UpdateReportStatus(ctx context.Context, reportID, status, reviewReason string) error {
	result, err := p.pool.Exec(ctx, `
		UPDATE reports
		SET status = $2, review_reason = $3, updated_at = $4
		WHERE id = $1 AND status != $5
	`, reportID, status, reviewReason, time.Now(), models.StatusDeleted)
	if err != nil {
		return fmt.Errorf("failed to update report status: %w", err)
	}

	if result.RowsAffected() == 0 {
		return errors.New("report not found")
	}

	return nil
}

// scanReportsWithMedia is a helper to scan report rows and fetch their media files
func (p *PostgresClient) scanReportsWithMedia(ctx context.Context, rows pgx.Rows) ([]models.TrafficReport, error) {
	var reports []models.TrafficReport
	for rows.Next() {
		var report models.TrafficReport
		if err := rows.Scan(
			&report.ID, &report.UserID, &report.Title, &report.Description, &report.DateTime,
			&report.RoadUsage, &report.EventType, &report.State, &report.City, &report.Injuries,
			&report.Status, &report.CreatedAt, &report.UpdatedAt, &report.ReviewReason,
		); err != nil {
			return nil, fmt.Errorf("failed to scan report: %w", err)
		}
		report.MediaFiles = []models.MediaFile{}
		reports = append(reports, report)
	}

	// Get media files for all reports
	if len(reports) > 0 {
		reportIDs := make([]string, len(reports))
		reportMap := make(map[string]*models.TrafficReport)
		for i := range reports {
			reportIDs[i] = reports[i].ID
			reportMap[reports[i].ID] = &reports[i]
		}

		mediaRows, err := p.pool.Query(ctx, `
			SELECT report_id, id, file_name, content_type, size, url, uploaded_at
			FROM media_files WHERE report_id = ANY($1)
		`, reportIDs)
		if err != nil {
			return nil, fmt.Errorf("failed to get media files: %w", err)
		}
		defer mediaRows.Close()

		for mediaRows.Next() {
			var reportID string
			var mf models.MediaFile
			if err := mediaRows.Scan(&reportID, &mf.ID, &mf.FileName, &mf.ContentType, &mf.Size, &mf.URL, &mf.UploadedAt); err != nil {
				return nil, fmt.Errorf("failed to scan media file: %w", err)
			}
			if r, ok := reportMap[reportID]; ok {
				r.MediaFiles = append(r.MediaFiles, mf)
			}
		}
	}

	if reports == nil {
		reports = []models.TrafficReport{}
	}

	return reports, nil
}

// ============================================================================
// User Management Methods
// ============================================================================

// CreateOrUpdateUser creates a new user or updates an existing one
func (p *PostgresClient) CreateOrUpdateUser(ctx context.Context, user *models.User) error {
	now := time.Now()
	_, err := p.pool.Exec(ctx, `
		INSERT INTO users (id, email, role, jwt_refresh_token, created_at, updated_at, last_login_at)
		VALUES ($1, $2, $3, $4, $5, $5, $5)
		ON CONFLICT (id) DO UPDATE SET
			email = EXCLUDED.email,
			role = EXCLUDED.role,
			jwt_refresh_token = EXCLUDED.jwt_refresh_token,
			updated_at = $5,
			last_login_at = $5
	`, user.ID, user.Email, user.Role, user.JWTRefreshToken, now)
	if err != nil {
		return fmt.Errorf("failed to create/update user: %w", err)
	}
	return nil
}

// GetUserByID retrieves a user by their ID (Google subject)
func (p *PostgresClient) GetUserByID(ctx context.Context, userID string) (*models.User, error) {
	user := &models.User{}
	err := p.pool.QueryRow(ctx, `
		SELECT id, email, role, COALESCE(jwt_refresh_token, ''), created_at, updated_at, last_login_at
		FROM users WHERE id = $1
	`, userID).Scan(&user.ID, &user.Email, &user.Role, &user.JWTRefreshToken,
		&user.CreatedAt, &user.UpdatedAt, &user.LastLoginAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("user not found")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	return user, nil
}

// GetUserByEmail retrieves a user by their email
func (p *PostgresClient) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	user := &models.User{}
	err := p.pool.QueryRow(ctx, `
		SELECT id, email, role, COALESCE(jwt_refresh_token, ''), created_at, updated_at, last_login_at
		FROM users WHERE email = $1
	`, email).Scan(&user.ID, &user.Email, &user.Role, &user.JWTRefreshToken,
		&user.CreatedAt, &user.UpdatedAt, &user.LastLoginAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("user not found")
		}
		return nil, fmt.Errorf("failed to get user by email: %w", err)
	}
	return user, nil
}

// UpdateUserRefreshToken updates the user's JWT refresh token
func (p *PostgresClient) UpdateUserRefreshToken(ctx context.Context, userID, refreshToken string) error {
	_, err := p.pool.Exec(ctx, `
		UPDATE users SET jwt_refresh_token = $2, updated_at = NOW() WHERE id = $1
	`, userID, refreshToken)
	if err != nil {
		return fmt.Errorf("failed to update refresh token: %w", err)
	}
	return nil
}

// UpdateUserLastLogin updates the user's last login timestamp
func (p *PostgresClient) UpdateUserLastLogin(ctx context.Context, userID string) error {
	_, err := p.pool.Exec(ctx, `
		UPDATE users SET last_login_at = NOW(), updated_at = NOW() WHERE id = $1
	`, userID)
	if err != nil {
		return fmt.Errorf("failed to update last login: %w", err)
	}
	return nil
}

// RevokeUserToken revokes the user's current token by clearing the refresh token
func (p *PostgresClient) RevokeUserToken(ctx context.Context, userID string) error {
	_, err := p.pool.Exec(ctx, `
		UPDATE users SET jwt_refresh_token = NULL, updated_at = NOW() WHERE id = $1
	`, userID)
	if err != nil {
		return fmt.Errorf("failed to revoke token: %w", err)
	}
	return nil
}
