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
}
