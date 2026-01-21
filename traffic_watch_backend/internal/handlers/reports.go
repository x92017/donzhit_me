package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"traffic_watch_backend/internal/middleware"
	"traffic_watch_backend/internal/models"
	"traffic_watch_backend/internal/storage"
	"traffic_watch_backend/internal/validation"
)

// ReportsHandler handles report-related requests
type ReportsHandler struct {
	firestore *storage.FirestoreClient
	gcs       *storage.GCSClient
}

// NewReportsHandler creates a new reports handler
func NewReportsHandler(firestore *storage.FirestoreClient, gcs *storage.GCSClient) *ReportsHandler {
	return &ReportsHandler{
		firestore: firestore,
		gcs:       gcs,
	}
}

// CreateReport handles POST /v1/reports
func (h *ReportsHandler) CreateReport(c *gin.Context) {
	user := middleware.RequireUser(c)
	if user == nil {
		return
	}

	contentType := c.GetHeader("Content-Type")

	// Handle multipart form data
	if strings.HasPrefix(contentType, "multipart/form-data") {
		h.createReportMultipart(c, user)
		return
	}

	// Handle JSON
	h.createReportJSON(c, user)
}

// createReportJSON handles JSON report creation
func (h *ReportsHandler) createReportJSON(c *gin.Context, user *models.UserInfo) {
	var req models.CreateReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": err.Error(),
		})
		return
	}

	report := &models.TrafficReport{
		ID:          uuid.New().String(),
		UserID:      user.Subject,
		Title:       req.Title,
		Description: req.Description,
		DateTime:    req.DateTime,
		RoadUsage:   req.RoadUsage,
		EventType:   req.EventType,
		State:       req.State,
		Injuries:    req.Injuries,
		MediaFiles:  []models.MediaFile{},
		Status:      models.StatusActive,
	}

	if err := h.firestore.CreateReport(c.Request.Context(), report); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "create_failed",
			"message": "failed to create report",
		})
		return
	}

	c.JSON(http.StatusCreated, report)
}

// createReportMultipart handles multipart form data report creation
func (h *ReportsHandler) createReportMultipart(c *gin.Context, user *models.UserInfo) {
	// Parse form values
	title := c.PostForm("title")
	description := c.PostForm("description")
	dateTimeStr := c.PostForm("dateTime")
	roadUsage := c.PostForm("roadUsage")
	eventType := c.PostForm("eventType")
	state := c.PostForm("state")
	injuries := c.PostForm("injuries")

	// Parse datetime
	dateTime, err := time.Parse(time.RFC3339, dateTimeStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "invalid dateTime format, expected RFC3339",
		})
		return
	}

	// Validate required fields
	if title == "" || description == "" || roadUsage == "" || eventType == "" || state == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "missing required fields",
		})
		return
	}

	// Validate field lengths
	if len(title) > 200 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "title exceeds maximum length of 200 characters",
		})
		return
	}
	if len(description) > 5000 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "description exceeds maximum length of 5000 characters",
		})
		return
	}

	reportID := uuid.New().String()

	// Handle file uploads
	form, err := c.MultipartForm()
	var mediaFiles []models.MediaFile

	if err == nil && form != nil && form.File != nil {
		files := form.File["files"]
		for _, fileHeader := range files {
			// Validate file
			valid, errMsg := validation.ValidateFile(fileHeader)
			if !valid {
				c.JSON(http.StatusBadRequest, gin.H{
					"error":   "validation_error",
					"message": errMsg,
				})
				return
			}

			// Open file
			file, err := fileHeader.Open()
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{
					"error":   "upload_failed",
					"message": "failed to process uploaded file",
				})
				return
			}

			fileID := uuid.New().String()
			contentType := fileHeader.Header.Get("Content-Type")
			safeFileName := validation.SanitizeFileName(fileHeader.Filename)

			// Upload to GCS
			objectPath, err := h.gcs.UploadFile(
				c.Request.Context(),
				user.Subject,
				reportID,
				fileID,
				contentType,
				file,
			)
			file.Close()

			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{
					"error":   "upload_failed",
					"message": "failed to upload file to storage",
				})
				return
			}

			// Generate signed URL
			signedURL, err := h.gcs.GetSignedURL(c.Request.Context(), objectPath, 0)
			if err != nil {
				signedURL = "" // URL will be generated on demand
			}

			mediaFiles = append(mediaFiles, models.MediaFile{
				ID:          fileID,
				FileName:    safeFileName,
				ContentType: contentType,
				Size:        fileHeader.Size,
				URL:         signedURL,
				UploadedAt:  time.Now(),
			})
		}
	}

	report := &models.TrafficReport{
		ID:          reportID,
		UserID:      user.Subject,
		Title:       title,
		Description: description,
		DateTime:    dateTime,
		RoadUsage:   roadUsage,
		EventType:   eventType,
		State:       state,
		Injuries:    injuries,
		MediaFiles:  mediaFiles,
		Status:      models.StatusActive,
	}

	if err := h.firestore.CreateReport(c.Request.Context(), report); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "create_failed",
			"message": "failed to create report",
		})
		return
	}

	c.JSON(http.StatusCreated, report)
}

// ListReports handles GET /v1/reports
func (h *ReportsHandler) ListReports(c *gin.Context) {
	user := middleware.RequireUser(c)
	if user == nil {
		return
	}

	reports, err := h.firestore.ListReportsByUser(c.Request.Context(), user.Subject)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "fetch_failed",
			"message": "failed to fetch reports",
		})
		return
	}

	if reports == nil {
		reports = []models.TrafficReport{}
	}

	// Refresh signed URLs for media files
	for i := range reports {
		for j := range reports[i].MediaFiles {
			objectPath := fmt.Sprintf("users/%s/reports/%s/%s",
				user.Subject,
				reports[i].ID,
				reports[i].MediaFiles[j].ID,
			)
			signedURL, err := h.gcs.GetSignedURL(c.Request.Context(), objectPath, 0)
			if err == nil {
				reports[i].MediaFiles[j].URL = signedURL
			}
		}
	}

	c.JSON(http.StatusOK, models.ListReportsResponse{
		Reports: reports,
		Count:   len(reports),
	})
}

// GetReport handles GET /v1/reports/:id
func (h *ReportsHandler) GetReport(c *gin.Context) {
	user := middleware.RequireUser(c)
	if user == nil {
		return
	}

	reportID := c.Param("id")
	if !validation.ValidateUUID(reportID) {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "invalid report ID format",
		})
		return
	}

	report, err := h.firestore.GetReportByIDAndUser(c.Request.Context(), reportID, user.Subject)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error":   "not_found",
			"message": "report not found",
		})
		return
	}

	// Refresh signed URLs for media files
	for i := range report.MediaFiles {
		objectPath := fmt.Sprintf("users/%s/reports/%s/%s",
			user.Subject,
			report.ID,
			report.MediaFiles[i].ID,
		)
		signedURL, err := h.gcs.GetSignedURL(c.Request.Context(), objectPath, 0)
		if err == nil {
			report.MediaFiles[i].URL = signedURL
		}
	}

	c.JSON(http.StatusOK, report)
}

// DeleteReport handles DELETE /v1/reports/:id
func (h *ReportsHandler) DeleteReport(c *gin.Context) {
	user := middleware.RequireUser(c)
	if user == nil {
		return
	}

	reportID := c.Param("id")
	if !validation.ValidateUUID(reportID) {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "invalid report ID format",
		})
		return
	}

	// Verify ownership and delete
	if err := h.firestore.DeleteReport(c.Request.Context(), reportID, user.Subject); err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error":   "not_found",
			"message": "report not found",
		})
		return
	}

	// Note: We don't delete files from GCS immediately for soft delete
	// A separate cleanup job could handle permanent deletions

	c.JSON(http.StatusOK, gin.H{
		"message": "report deleted successfully",
	})
}
