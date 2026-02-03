package storage

import (
	"context"

	"donzhit_me_backend/internal/models"
)

// Client defines the interface for storage backends
// Both FirestoreClient and PostgresClient implement this interface
type Client interface {
	// Close closes the storage connection
	Close() error

	// CreateReport creates a new report
	CreateReport(ctx context.Context, report *models.TrafficReport) error

	// GetReport retrieves a report by ID
	GetReport(ctx context.Context, reportID string) (*models.TrafficReport, error)

	// GetReportByIDAndUser retrieves a report by ID and verifies user ownership
	GetReportByIDAndUser(ctx context.Context, reportID, userID string) (*models.TrafficReport, error)

	// ListReportsByUser retrieves all active reports for a user
	ListReportsByUser(ctx context.Context, userID string) ([]models.TrafficReport, error)

	// UpdateReport updates an existing report
	UpdateReport(ctx context.Context, report *models.TrafficReport) error

	// DeleteReport performs a soft delete on a report
	DeleteReport(ctx context.Context, reportID, userID string) error

	// AddMediaFileToReport adds a media file reference to a report
	AddMediaFileToReport(ctx context.Context, reportID string, mediaFile models.MediaFile) error

	// ListAllReports retrieves all non-deleted reports (for admin dashboard)
	ListAllReports(ctx context.Context) ([]models.TrafficReport, error)

	// ListReportsAwaitingReview retrieves reports with "submitted" status (for admin review queue)
	ListReportsAwaitingReview(ctx context.Context) ([]models.TrafficReport, error)

	// ListApprovedReports retrieves reports with "reviewed_pass" status (for public feed)
	ListApprovedReports(ctx context.Context) ([]models.TrafficReport, error)

	// UpdateReportStatus updates a report's status and optional review reason
	UpdateReportStatus(ctx context.Context, reportID, status, reviewReason string) error

	// User management methods

	// CreateOrUpdateUser creates a new user or updates an existing one
	CreateOrUpdateUser(ctx context.Context, user *models.User) error

	// GetUserByID retrieves a user by their ID (Google subject)
	GetUserByID(ctx context.Context, userID string) (*models.User, error)

	// GetUserByEmail retrieves a user by their email
	GetUserByEmail(ctx context.Context, email string) (*models.User, error)

	// UpdateUserRefreshToken updates the user's JWT refresh token
	UpdateUserRefreshToken(ctx context.Context, userID, refreshToken string) error

	// UpdateUserLastLogin updates the user's last login timestamp
	UpdateUserLastLogin(ctx context.Context, userID string) error

	// RevokeUserToken revokes the user's current token by clearing the refresh token
	RevokeUserToken(ctx context.Context, userID string) error
}
