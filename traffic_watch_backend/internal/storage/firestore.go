package storage

import (
	"context"
	"errors"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"

	"donzhit_me_backend/internal/models"
)

const (
	// Collection names
	reportsCollection = "reports"
)

// FirestoreClient wraps the Firestore client
type FirestoreClient struct {
	client    *firestore.Client
	projectID string
}

// NewFirestoreClient creates a new Firestore client
func NewFirestoreClient(ctx context.Context, projectID string) (*FirestoreClient, error) {
	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		return nil, err
	}

	return &FirestoreClient{
		client:    client,
		projectID: projectID,
	}, nil
}

// Close closes the Firestore client
func (f *FirestoreClient) Close() error {
	return f.client.Close()
}

// CreateReport creates a new report in Firestore
func (f *FirestoreClient) CreateReport(ctx context.Context, report *models.TrafficReport) error {
	if report.ID == "" {
		return errors.New("report ID is required")
	}

	report.CreatedAt = time.Now()
	report.UpdatedAt = time.Now()
	report.Status = models.StatusActive

	_, err := f.client.Collection(reportsCollection).Doc(report.ID).Set(ctx, report)
	return err
}

// GetReport retrieves a report by ID
func (f *FirestoreClient) GetReport(ctx context.Context, reportID string) (*models.TrafficReport, error) {
	doc, err := f.client.Collection(reportsCollection).Doc(reportID).Get(ctx)
	if err != nil {
		return nil, err
	}

	var report models.TrafficReport
	if err := doc.DataTo(&report); err != nil {
		return nil, err
	}

	return &report, nil
}

// GetReportByIDAndUser retrieves a report by ID and verifies user ownership
func (f *FirestoreClient) GetReportByIDAndUser(ctx context.Context, reportID, userID string) (*models.TrafficReport, error) {
	report, err := f.GetReport(ctx, reportID)
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

// ListReportsByUser retrieves all reports for a user
func (f *FirestoreClient) ListReportsByUser(ctx context.Context, userID string) ([]models.TrafficReport, error) {
	iter := f.client.Collection(reportsCollection).
		Where("userId", "==", userID).
		Where("status", "==", models.StatusActive).
		OrderBy("createdAt", firestore.Desc).
		Documents(ctx)

	var reports []models.TrafficReport
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, err
		}

		var report models.TrafficReport
		if err := doc.DataTo(&report); err != nil {
			continue
		}
		reports = append(reports, report)
	}

	return reports, nil
}

// UpdateReport updates an existing report
func (f *FirestoreClient) UpdateReport(ctx context.Context, report *models.TrafficReport) error {
	report.UpdatedAt = time.Now()

	_, err := f.client.Collection(reportsCollection).Doc(report.ID).Set(ctx, report)
	return err
}

// DeleteReport performs a soft delete on a report
func (f *FirestoreClient) DeleteReport(ctx context.Context, reportID, userID string) error {
	report, err := f.GetReportByIDAndUser(ctx, reportID, userID)
	if err != nil {
		return err
	}

	report.Status = models.StatusDeleted
	report.UpdatedAt = time.Now()

	_, err = f.client.Collection(reportsCollection).Doc(reportID).Set(ctx, report)
	return err
}

// AddMediaFileToReport adds a media file reference to a report
func (f *FirestoreClient) AddMediaFileToReport(ctx context.Context, reportID string, mediaFile models.MediaFile) error {
	report, err := f.GetReport(ctx, reportID)
	if err != nil {
		return err
	}

	report.MediaFiles = append(report.MediaFiles, mediaFile)
	report.UpdatedAt = time.Now()

	_, err = f.client.Collection(reportsCollection).Doc(reportID).Set(ctx, report)
	return err
}
