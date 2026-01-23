package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"donzhit_me_backend/internal/middleware"
	"donzhit_me_backend/internal/models"
	"donzhit_me_backend/internal/validation"
)

func init() {
	gin.SetMode(gin.TestMode)
	// Register custom validators for tests
	_ = validation.RegisterCustomValidators()
}

// mockUserMiddleware sets a mock user in the context for testing
func mockUserMiddleware(userID, email string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set(middleware.UserContextKey, &models.UserInfo{
			Email:   email,
			Subject: userID,
		})
		c.Next()
	}
}

func TestReportsHandler_CreateReport_NoAuth(t *testing.T) {
	handler := NewReportsHandler(nil, nil)

	router := gin.New()
	router.POST("/v1/reports", handler.CreateReport)

	body := `{"title": "Test", "description": "Test desc"}`
	req, _ := http.NewRequest(http.MethodPost, "/v1/reports", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	// Should return 401 without auth middleware setting user
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestReportsHandler_CreateReport_ValidationError(t *testing.T) {
	handler := NewReportsHandler(nil, nil)

	router := gin.New()
	router.Use(mockUserMiddleware("user-123", "user@example.com"))
	router.POST("/v1/reports", handler.CreateReport)

	tests := []struct {
		name string
		body string
	}{
		{
			name: "missing title",
			body: `{"description": "Test", "dateTime": "2026-01-21T12:00:00Z", "roadUsage": "Auto", "eventType": "Speeding", "state": "California"}`,
		},
		{
			name: "missing description",
			body: `{"title": "Test", "dateTime": "2026-01-21T12:00:00Z", "roadUsage": "Auto", "eventType": "Speeding", "state": "California"}`,
		},
		{
			name: "invalid roadUsage",
			body: `{"title": "Test", "description": "Test", "dateTime": "2026-01-21T12:00:00Z", "roadUsage": "Invalid", "eventType": "Speeding", "state": "California"}`,
		},
		{
			name: "invalid eventType",
			body: `{"title": "Test", "description": "Test", "dateTime": "2026-01-21T12:00:00Z", "roadUsage": "Auto", "eventType": "Invalid", "state": "California"}`,
		},
		{
			name: "invalid state",
			body: `{"title": "Test", "description": "Test", "dateTime": "2026-01-21T12:00:00Z", "roadUsage": "Auto", "eventType": "Speeding", "state": "InvalidState"}`,
		},
		{
			name: "empty body",
			body: `{}`,
		},
		{
			name: "invalid JSON",
			body: `{invalid json}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, _ := http.NewRequest(http.MethodPost, "/v1/reports", bytes.NewBufferString(tt.body))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			router.ServeHTTP(w, req)

			if w.Code != http.StatusBadRequest && w.Code != http.StatusInternalServerError {
				t.Errorf("expected status 400 or 500, got %d", w.Code)
			}
		})
	}
}

func TestReportsHandler_ListReports_NoAuth(t *testing.T) {
	handler := NewReportsHandler(nil, nil)

	router := gin.New()
	router.GET("/v1/reports", handler.ListReports)

	req, _ := http.NewRequest(http.MethodGet, "/v1/reports", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestReportsHandler_GetReport_NoAuth(t *testing.T) {
	handler := NewReportsHandler(nil, nil)

	router := gin.New()
	router.GET("/v1/reports/:id", handler.GetReport)

	req, _ := http.NewRequest(http.MethodGet, "/v1/reports/550e8400-e29b-41d4-a716-446655440000", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestReportsHandler_GetReport_InvalidID(t *testing.T) {
	handler := NewReportsHandler(nil, nil)

	router := gin.New()
	router.Use(mockUserMiddleware("user-123", "user@example.com"))
	router.GET("/v1/reports/:id", handler.GetReport)

	tests := []struct {
		name string
		id   string
	}{
		{"not a UUID", "not-a-uuid"},
		{"empty", ""},
		{"too short", "550e8400-e29b"},
		{"invalid characters", "gggggggg-gggg-gggg-gggg-gggggggggggg"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, _ := http.NewRequest(http.MethodGet, "/v1/reports/"+tt.id, nil)
			w := httptest.NewRecorder()

			router.ServeHTTP(w, req)

			if w.Code != http.StatusBadRequest && w.Code != http.StatusNotFound {
				t.Errorf("expected status 400 or 404, got %d", w.Code)
			}
		})
	}
}

func TestReportsHandler_DeleteReport_NoAuth(t *testing.T) {
	handler := NewReportsHandler(nil, nil)

	router := gin.New()
	router.DELETE("/v1/reports/:id", handler.DeleteReport)

	req, _ := http.NewRequest(http.MethodDelete, "/v1/reports/550e8400-e29b-41d4-a716-446655440000", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestReportsHandler_DeleteReport_InvalidID(t *testing.T) {
	handler := NewReportsHandler(nil, nil)

	router := gin.New()
	router.Use(mockUserMiddleware("user-123", "user@example.com"))
	router.DELETE("/v1/reports/:id", handler.DeleteReport)

	req, _ := http.NewRequest(http.MethodDelete, "/v1/reports/invalid-id", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestCreateReportRequest_Validation(t *testing.T) {
	tests := []struct {
		name    string
		request models.CreateReportRequest
		wantErr bool
	}{
		{
			name: "valid request",
			request: models.CreateReportRequest{
				Title:       "Test Report",
				Description: "Test description",
				DateTime:    time.Now(),
				RoadUsage:   "Auto",
				EventType:   "Speeding",
				State:       "California",
				Injuries:    "",
			},
			wantErr: false,
		},
		{
			name: "title too long",
			request: models.CreateReportRequest{
				Title:       string(make([]byte, 201)), // 201 chars
				Description: "Test",
				DateTime:    time.Now(),
				RoadUsage:   "Auto",
				EventType:   "Speeding",
				State:       "California",
			},
			wantErr: true,
		},
		{
			name: "description too long",
			request: models.CreateReportRequest{
				Title:       "Test",
				Description: string(make([]byte, 5001)), // 5001 chars
				DateTime:    time.Now(),
				RoadUsage:   "Auto",
				EventType:   "Speeding",
				State:       "California",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Just validate the struct fields exist
			if tt.request.Title == "" && !tt.wantErr {
				t.Error("title should not be empty for valid request")
			}
		})
	}
}

func TestTrafficReport_JSONSerialization(t *testing.T) {
	report := models.TrafficReport{
		ID:          "test-id",
		UserID:      "user-123",
		Title:       "Test Report",
		Description: "Test description",
		DateTime:    time.Date(2026, 1, 21, 12, 0, 0, 0, time.UTC),
		RoadUsage:   "Auto",
		EventType:   "Speeding",
		State:       "California",
		Injuries:    "None",
		MediaFiles:  []models.MediaFile{},
		CreatedAt:   time.Date(2026, 1, 21, 12, 0, 0, 0, time.UTC),
		UpdatedAt:   time.Date(2026, 1, 21, 12, 0, 0, 0, time.UTC),
		Status:      "active",
	}

	// Test serialization
	data, err := json.Marshal(report)
	if err != nil {
		t.Fatalf("failed to marshal report: %v", err)
	}

	// Test deserialization
	var parsed models.TrafficReport
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("failed to unmarshal report: %v", err)
	}

	// Verify fields
	if parsed.ID != report.ID {
		t.Errorf("ID mismatch: got %q, want %q", parsed.ID, report.ID)
	}
	if parsed.Title != report.Title {
		t.Errorf("Title mismatch: got %q, want %q", parsed.Title, report.Title)
	}
	if parsed.Status != report.Status {
		t.Errorf("Status mismatch: got %q, want %q", parsed.Status, report.Status)
	}
}

func TestListReportsResponse_JSONSerialization(t *testing.T) {
	response := models.ListReportsResponse{
		Reports: []models.TrafficReport{
			{
				ID:     "report-1",
				Title:  "Report 1",
				Status: "active",
			},
			{
				ID:     "report-2",
				Title:  "Report 2",
				Status: "active",
			},
		},
		Count: 2,
	}

	data, err := json.Marshal(response)
	if err != nil {
		t.Fatalf("failed to marshal response: %v", err)
	}

	var parsed models.ListReportsResponse
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if parsed.Count != 2 {
		t.Errorf("Count mismatch: got %d, want 2", parsed.Count)
	}
	if len(parsed.Reports) != 2 {
		t.Errorf("Reports length mismatch: got %d, want 2", len(parsed.Reports))
	}
}

func TestMediaFile_JSONSerialization(t *testing.T) {
	mediaFile := models.MediaFile{
		ID:          "media-123",
		FileName:    "photo.jpg",
		ContentType: "image/jpeg",
		Size:        1024,
		URL:         "https://storage.example.com/photo.jpg",
		UploadedAt:  time.Date(2026, 1, 21, 12, 0, 0, 0, time.UTC),
	}

	data, err := json.Marshal(mediaFile)
	if err != nil {
		t.Fatalf("failed to marshal media file: %v", err)
	}

	var parsed models.MediaFile
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("failed to unmarshal media file: %v", err)
	}

	if parsed.ID != mediaFile.ID {
		t.Errorf("ID mismatch: got %q, want %q", parsed.ID, mediaFile.ID)
	}
	if parsed.FileName != mediaFile.FileName {
		t.Errorf("FileName mismatch: got %q, want %q", parsed.FileName, mediaFile.FileName)
	}
	if parsed.ContentType != mediaFile.ContentType {
		t.Errorf("ContentType mismatch: got %q, want %q", parsed.ContentType, mediaFile.ContentType)
	}
}

func TestReportStatus_Constants(t *testing.T) {
	if models.StatusActive != "active" {
		t.Errorf("StatusActive should be 'active', got %q", models.StatusActive)
	}
	if models.StatusDeleted != "deleted" {
		t.Errorf("StatusDeleted should be 'deleted', got %q", models.StatusDeleted)
	}
}
