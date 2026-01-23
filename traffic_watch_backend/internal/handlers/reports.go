package handlers

import (
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"donzhit_me_backend/internal/middleware"
	"donzhit_me_backend/internal/models"
	"donzhit_me_backend/internal/storage"
	"donzhit_me_backend/internal/validation"
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
		log.Printf("Validation error for user %s: %v", user.Email, err)
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": err.Error(),
			"details": fmt.Sprintf("%v", err),
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

	log.Printf("Multipart form received - title: %s, roadUsage: %s, eventType: %s, state: %s, dateTime: %s",
		title, roadUsage, eventType, state, dateTimeStr)

	// Parse datetime - try multiple formats
	var dateTime time.Time
	var err error
	dateFormats := []string{
		time.RFC3339,
		time.RFC3339Nano,
		"2006-01-02T15:04:05.999999999",  // ISO8601 without timezone
		"2006-01-02T15:04:05.999999",     // ISO8601 with microseconds
		"2006-01-02T15:04:05",            // ISO8601 basic
	}
	for _, format := range dateFormats {
		dateTime, err = time.Parse(format, dateTimeStr)
		if err == nil {
			break
		}
	}
	if err != nil {
		log.Printf("DateTime parse error for user %s: %v (received: %s)", user.Email, err, dateTimeStr)
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": fmt.Sprintf("invalid dateTime format: %s", dateTimeStr),
		})
		return
	}

	// Validate required fields
	if title == "" || description == "" || roadUsage == "" || eventType == "" || state == "" {
		log.Printf("Missing required fields for user %s - title:%v desc:%v roadUsage:%v eventType:%v state:%v",
			user.Email, title != "", description != "", roadUsage != "", eventType != "", state != "")
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

	log.Printf("Processing file uploads for user %s", user.Email)
	if err == nil && form != nil && form.File != nil {
		files := form.File["files"]
		log.Printf("Found %d files to upload", len(files))
		for i, fileHeader := range files {
			log.Printf("Processing file %d: %s (size: %d, content-type: %s)",
				i, fileHeader.Filename, fileHeader.Size, fileHeader.Header.Get("Content-Type"))
			// Validate file
			valid, errMsg := validation.ValidateFile(fileHeader)
			if !valid {
				log.Printf("File validation failed for %s: %s", fileHeader.Filename, errMsg)
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
			// Detect content type from extension if not properly set
			if contentType == "" || contentType == "application/octet-stream" {
				contentType = validation.DetectContentType(fileHeader.Filename)
			}
			safeFileName := validation.SanitizeFileName(fileHeader.Filename)

			// Upload to GCS
			log.Printf("Uploading file %s to GCS", fileHeader.Filename)
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
				log.Printf("GCS upload failed for %s: %v", fileHeader.Filename, err)
				c.JSON(http.StatusInternalServerError, gin.H{
					"error":   "upload_failed",
					"message": "failed to upload file to storage",
				})
				return
			}
			log.Printf("File uploaded successfully to %s", objectPath)

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

	log.Printf("Creating report %s in Firestore for user %s", reportID, user.Email)
	if err := h.firestore.CreateReport(c.Request.Context(), report); err != nil {
		log.Printf("Firestore create failed for report %s: %v", reportID, err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "create_failed",
			"message": "failed to create report",
		})
		return
	}

	log.Printf("Report %s created successfully", reportID)
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
