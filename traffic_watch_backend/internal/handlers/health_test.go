package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func TestHealthHandler_Health(t *testing.T) {
	handler := NewHealthHandler("1.0.0")

	router := gin.New()
	router.GET("/v1/health", handler.Health)

	req, _ := http.NewRequest(http.MethodGet, "/v1/health", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	// Check status code
	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	// Parse response
	var response HealthResponse
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	// Check response fields
	if response.Status != "healthy" {
		t.Errorf("expected status 'healthy', got %q", response.Status)
	}

	if response.Version != "1.0.0" {
		t.Errorf("expected version '1.0.0', got %q", response.Version)
	}

	if response.Timestamp == "" {
		t.Error("expected timestamp to be set")
	}
}

func TestHealthHandler_DifferentVersions(t *testing.T) {
	tests := []struct {
		name    string
		version string
	}{
		{"version 1.0.0", "1.0.0"},
		{"version 2.0.0-beta", "2.0.0-beta"},
		{"version with commit", "1.0.0-abc123"},
		{"empty version", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := NewHealthHandler(tt.version)

			router := gin.New()
			router.GET("/v1/health", handler.Health)

			req, _ := http.NewRequest(http.MethodGet, "/v1/health", nil)
			w := httptest.NewRecorder()

			router.ServeHTTP(w, req)

			var response HealthResponse
			if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
				t.Fatalf("failed to parse response: %v", err)
			}

			if response.Version != tt.version {
				t.Errorf("expected version %q, got %q", tt.version, response.Version)
			}
		})
	}
}

func TestHealthHandler_ContentType(t *testing.T) {
	handler := NewHealthHandler("1.0.0")

	router := gin.New()
	router.GET("/v1/health", handler.Health)

	req, _ := http.NewRequest(http.MethodGet, "/v1/health", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json; charset=utf-8" {
		t.Errorf("expected Content-Type 'application/json; charset=utf-8', got %q", contentType)
	}
}

func TestNewHealthHandler(t *testing.T) {
	handler := NewHealthHandler("test-version")
	if handler == nil {
		t.Error("expected handler to be created")
	}
	if handler.version != "test-version" {
		t.Errorf("expected version 'test-version', got %q", handler.version)
	}
}
