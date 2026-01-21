package storage

import (
	"context"
	"fmt"
	"io"
	"path"
	"time"

	"cloud.google.com/go/storage"

	"traffic_watch_backend/internal/validation"
)

const (
	// Default signed URL expiration
	defaultURLExpiration = 1 * time.Hour

	// Upload URL expiration (for resumable uploads)
	uploadURLExpiration = 15 * time.Minute
)

// GCSClient wraps the Google Cloud Storage client
type GCSClient struct {
	client     *storage.Client
	bucketName string
}

// NewGCSClient creates a new GCS client
func NewGCSClient(ctx context.Context, bucketName string) (*GCSClient, error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return nil, err
	}

	return &GCSClient{
		client:     client,
		bucketName: bucketName,
	}, nil
}

// Close closes the GCS client
func (g *GCSClient) Close() error {
	return g.client.Close()
}

// UploadFile uploads a file to GCS
func (g *GCSClient) UploadFile(ctx context.Context, userID, reportID, fileID string, contentType string, reader io.Reader) (string, error) {
	objectPath := g.getObjectPath(userID, reportID, fileID)

	bucket := g.client.Bucket(g.bucketName)
	obj := bucket.Object(objectPath)

	writer := obj.NewWriter(ctx)
	writer.ContentType = contentType
	writer.CacheControl = "private, max-age=3600"

	if _, err := io.Copy(writer, reader); err != nil {
		writer.Close()
		return "", fmt.Errorf("failed to upload file: %w", err)
	}

	if err := writer.Close(); err != nil {
		return "", fmt.Errorf("failed to close writer: %w", err)
	}

	return objectPath, nil
}

// GetSignedURL generates a signed URL for reading a file
func (g *GCSClient) GetSignedURL(ctx context.Context, objectPath string, expiration time.Duration) (string, error) {
	if expiration == 0 {
		expiration = defaultURLExpiration
	}

	opts := &storage.SignedURLOptions{
		Method:  "GET",
		Expires: time.Now().Add(expiration),
	}

	url, err := g.client.Bucket(g.bucketName).SignedURL(objectPath, opts)
	if err != nil {
		return "", fmt.Errorf("failed to generate signed URL: %w", err)
	}

	return url, nil
}

// GetUploadSignedURL generates a signed URL for uploading a file
func (g *GCSClient) GetUploadSignedURL(ctx context.Context, userID, reportID, fileID, contentType string) (string, string, error) {
	objectPath := g.getObjectPath(userID, reportID, fileID)

	opts := &storage.SignedURLOptions{
		Method:      "PUT",
		Expires:     time.Now().Add(uploadURLExpiration),
		ContentType: contentType,
	}

	url, err := g.client.Bucket(g.bucketName).SignedURL(objectPath, opts)
	if err != nil {
		return "", "", fmt.Errorf("failed to generate upload URL: %w", err)
	}

	return url, objectPath, nil
}

// DeleteFile deletes a file from GCS
func (g *GCSClient) DeleteFile(ctx context.Context, objectPath string) error {
	bucket := g.client.Bucket(g.bucketName)
	obj := bucket.Object(objectPath)

	if err := obj.Delete(ctx); err != nil {
		if err == storage.ErrObjectNotExist {
			return nil // Already deleted, not an error
		}
		return fmt.Errorf("failed to delete file: %w", err)
	}

	return nil
}

// DeleteReportFiles deletes all files associated with a report
func (g *GCSClient) DeleteReportFiles(ctx context.Context, userID, reportID string) error {
	prefix := fmt.Sprintf("users/%s/reports/%s/", userID, reportID)

	bucket := g.client.Bucket(g.bucketName)
	it := bucket.Objects(ctx, &storage.Query{Prefix: prefix})

	for {
		attrs, err := it.Next()
		if err == storage.ErrObjectNotExist {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to list objects: %w", err)
		}

		if err := bucket.Object(attrs.Name).Delete(ctx); err != nil && err != storage.ErrObjectNotExist {
			return fmt.Errorf("failed to delete object %s: %w", attrs.Name, err)
		}
	}

	return nil
}

// FileExists checks if a file exists in GCS
func (g *GCSClient) FileExists(ctx context.Context, objectPath string) (bool, error) {
	bucket := g.client.Bucket(g.bucketName)
	_, err := bucket.Object(objectPath).Attrs(ctx)

	if err == storage.ErrObjectNotExist {
		return false, nil
	}
	if err != nil {
		return false, err
	}

	return true, nil
}

// getObjectPath generates the object path for a file
func (g *GCSClient) getObjectPath(userID, reportID, fileID string) string {
	// Sanitize all path components
	safeUserID := validation.SanitizeFileName(userID)
	safeReportID := validation.SanitizeFileName(reportID)
	safeFileID := validation.SanitizeFileName(fileID)

	return path.Join("users", safeUserID, "reports", safeReportID, safeFileID)
}

// GetBucketName returns the bucket name
func (g *GCSClient) GetBucketName() string {
	return g.bucketName
}
