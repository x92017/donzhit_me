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
	report.Status = models.StatusSubmitted

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

// ListReportsByUser retrieves all non-deleted reports for a user
func (f *FirestoreClient) ListReportsByUser(ctx context.Context, userID string) ([]models.TrafficReport, error) {
	iter := f.client.Collection(reportsCollection).
		Where("userId", "==", userID).
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
		// Skip deleted reports
		if report.Status == models.StatusDeleted {
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

// ============================================================================
// Admin Report Methods (Firestore implementation)
// ============================================================================

// ListAllReports retrieves all non-deleted reports (for admin dashboard)
func (f *FirestoreClient) ListAllReports(ctx context.Context) ([]models.TrafficReport, error) {
	iter := f.client.Collection(reportsCollection).
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
		if report.Status == models.StatusDeleted {
			continue
		}
		reports = append(reports, report)
	}

	return reports, nil
}

// ListReportsAwaitingReview retrieves reports with "submitted" status (for admin review queue)
func (f *FirestoreClient) ListReportsAwaitingReview(ctx context.Context) ([]models.TrafficReport, error) {
	iter := f.client.Collection(reportsCollection).
		Where("status", "==", models.StatusSubmitted).
		OrderBy("createdAt", firestore.Asc).
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

// ListApprovedReports retrieves reports with "reviewed_pass" status (for public feed)
func (f *FirestoreClient) ListApprovedReports(ctx context.Context) ([]models.TrafficReport, error) {
	iter := f.client.Collection(reportsCollection).
		Where("status", "==", models.StatusReviewedPass).
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

// UpdateReportStatus updates a report's status and optional review reason
func (f *FirestoreClient) UpdateReportStatus(ctx context.Context, reportID, status, reviewReason string) error {
	report, err := f.GetReport(ctx, reportID)
	if err != nil {
		return err
	}

	if report.Status == models.StatusDeleted {
		return errors.New("report not found")
	}

	report.Status = status
	report.ReviewReason = reviewReason
	report.UpdatedAt = time.Now()

	_, err = f.client.Collection(reportsCollection).Doc(reportID).Set(ctx, report)
	return err
}

// ============================================================================
// User Management Methods (Firestore implementation)
// Note: For production use with Firestore, these would need proper implementation.
// Currently, JWT auth is designed for use with PostgreSQL backend.
// ============================================================================

const usersCollection = "users"

// CreateOrUpdateUser creates a new user or updates an existing one
func (f *FirestoreClient) CreateOrUpdateUser(ctx context.Context, user *models.User) error {
	now := time.Now()
	user.UpdatedAt = now
	if user.CreatedAt.IsZero() {
		user.CreatedAt = now
	}
	user.LastLoginAt = &now

	_, err := f.client.Collection(usersCollection).Doc(user.ID).Set(ctx, user)
	return err
}

// GetUserByID retrieves a user by their ID (Google subject)
func (f *FirestoreClient) GetUserByID(ctx context.Context, userID string) (*models.User, error) {
	doc, err := f.client.Collection(usersCollection).Doc(userID).Get(ctx)
	if err != nil {
		return nil, errors.New("user not found")
	}

	var user models.User
	if err := doc.DataTo(&user); err != nil {
		return nil, err
	}

	return &user, nil
}

// GetUserByEmail retrieves a user by their email
func (f *FirestoreClient) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	iter := f.client.Collection(usersCollection).
		Where("email", "==", email).
		Limit(1).
		Documents(ctx)

	doc, err := iter.Next()
	if err == iterator.Done {
		return nil, errors.New("user not found")
	}
	if err != nil {
		return nil, err
	}

	var user models.User
	if err := doc.DataTo(&user); err != nil {
		return nil, err
	}

	return &user, nil
}

// UpdateUserRefreshToken updates the user's JWT refresh token
func (f *FirestoreClient) UpdateUserRefreshToken(ctx context.Context, userID, refreshToken string) error {
	_, err := f.client.Collection(usersCollection).Doc(userID).Update(ctx, []firestore.Update{
		{Path: "jwtRefreshToken", Value: refreshToken},
		{Path: "updatedAt", Value: time.Now()},
	})
	return err
}

// UpdateUserLastLogin updates the user's last login timestamp
func (f *FirestoreClient) UpdateUserLastLogin(ctx context.Context, userID string) error {
	now := time.Now()
	_, err := f.client.Collection(usersCollection).Doc(userID).Update(ctx, []firestore.Update{
		{Path: "lastLoginAt", Value: now},
		{Path: "updatedAt", Value: now},
	})
	return err
}

// RevokeUserToken revokes the user's current token by clearing the refresh token
func (f *FirestoreClient) RevokeUserToken(ctx context.Context, userID string) error {
	_, err := f.client.Collection(usersCollection).Doc(userID).Update(ctx, []firestore.Update{
		{Path: "jwtRefreshToken", Value: ""},
		{Path: "updatedAt", Value: time.Now()},
	})
	return err
}
