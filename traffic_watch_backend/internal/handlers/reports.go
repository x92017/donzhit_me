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
	storage storage.Client
	gcs     *storage.GCSClient
	youtube *storage.YouTubeClient
}

// NewReportsHandler creates a new reports handler
func NewReportsHandler(storageClient storage.Client, gcs *storage.GCSClient, youtube *storage.YouTubeClient) *ReportsHandler {
	return &ReportsHandler{
		storage: storageClient,
		gcs:     gcs,
		youtube: youtube,
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
		RoadUsages:  req.RoadUsages,
		EventTypes:  req.EventTypes,
		State:       req.State,
		City:        req.City,
		Injuries:    req.Injuries,
		MediaFiles:  []models.MediaFile{},
		Status:      models.StatusSubmitted,
	}

	if err := h.storage.CreateReport(c.Request.Context(), report); err != nil {
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
	state := c.PostForm("state")
	city := c.PostForm("city")
	injuries := c.PostForm("injuries")

	// Parse array fields - support both comma-separated and multiple form values
	roadUsagesStr := c.PostForm("roadUsages")
	eventTypesStr := c.PostForm("eventTypes")

	var roadUsages []string
	var eventTypes []string

	// Parse roadUsages - try comma-separated first, then multiple form values
	if roadUsagesStr != "" {
		roadUsages = strings.Split(roadUsagesStr, ",")
		for i := range roadUsages {
			roadUsages[i] = strings.TrimSpace(roadUsages[i])
		}
	} else {
		roadUsages = c.PostFormArray("roadUsages[]")
	}

	// Parse eventTypes - try comma-separated first, then multiple form values
	if eventTypesStr != "" {
		eventTypes = strings.Split(eventTypesStr, ",")
		for i := range eventTypes {
			eventTypes[i] = strings.TrimSpace(eventTypes[i])
		}
	} else {
		eventTypes = c.PostFormArray("eventTypes[]")
	}

	log.Printf("Multipart form received - title: %s, roadUsages: %v, eventTypes: %v, state: %s, dateTime: %s",
		title, roadUsages, eventTypes, state, dateTimeStr)

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
	if title == "" || description == "" || len(roadUsages) == 0 || len(eventTypes) == 0 || state == "" {
		log.Printf("Missing required fields for user %s - title:%v desc:%v roadUsages:%v eventTypes:%v state:%v",
			user.Email, title != "", description != "", len(roadUsages) > 0, len(eventTypes) > 0, state != "")
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

			var mediaFile models.MediaFile

			// Check if it's a video and YouTube client is available
			if storage.IsVideoContentType(contentType) && h.youtube != nil {
				log.Printf("Uploading video %s to YouTube", fileHeader.Filename)

				// Create video title and description
				videoTitle := fmt.Sprintf("%s - %s", title, safeFileName)
				videoDesc := fmt.Sprintf("Traffic incident report: %s\n\nUploaded via DonzHit.me", description)

				result, err := h.youtube.UploadVideo(c.Request.Context(), videoTitle, videoDesc, file, contentType)
				file.Close()

				if err != nil {
					log.Printf("YouTube upload failed for %s: %v, falling back to GCS", fileHeader.Filename, err)
					// Fall back to GCS on YouTube failure
					file, _ = fileHeader.Open()
					mediaFile, err = h.uploadToGCS(c, user, reportID, fileID, contentType, safeFileName, fileHeader.Size, file)
					file.Close()
					if err != nil {
						return // Error response already sent
					}
				} else {
					log.Printf("Video uploaded to YouTube: %s", result.URL)
					mediaFile = models.MediaFile{
						ID:          result.VideoID, // Use YouTube video ID
						FileName:    safeFileName,
						ContentType: contentType,
						Size:        fileHeader.Size,
						URL:         result.URL,
						UploadedAt:  time.Now(),
					}
				}
			} else {
				// Upload images (and videos if no YouTube client) to GCS
				mediaFile, err = h.uploadToGCS(c, user, reportID, fileID, contentType, safeFileName, fileHeader.Size, file)
				file.Close()
				if err != nil {
					return // Error response already sent
				}
			}

			mediaFiles = append(mediaFiles, mediaFile)
		}
	}

	report := &models.TrafficReport{
		ID:          reportID,
		UserID:      user.Subject,
		Title:       title,
		Description: description,
		DateTime:    dateTime,
		RoadUsages:  roadUsages,
		EventTypes:  eventTypes,
		State:       state,
		City:        city,
		Injuries:    injuries,
		MediaFiles:  mediaFiles,
		Status:      models.StatusSubmitted,
	}

	log.Printf("Creating report %s in storage for user %s", reportID, user.Email)
	if err := h.storage.CreateReport(c.Request.Context(), report); err != nil {
		log.Printf("Storage create failed for report %s: %v", reportID, err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "create_failed",
			"message": "failed to create report",
		})
		return
	}

	log.Printf("Report %s created successfully", reportID)
	c.JSON(http.StatusCreated, report)
}

// uploadToGCS uploads a file to Google Cloud Storage
func (h *ReportsHandler) uploadToGCS(c *gin.Context, user *models.UserInfo, reportID, fileID, contentType, safeFileName string, size int64, file interface{}) (models.MediaFile, error) {
	log.Printf("Uploading file %s to GCS", safeFileName)

	reader, ok := file.(interface{ Read([]byte) (int, error) })
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "upload_failed",
			"message": "failed to read file",
		})
		return models.MediaFile{}, fmt.Errorf("invalid file reader")
	}

	objectPath, err := h.gcs.UploadFile(
		c.Request.Context(),
		user.Subject,
		reportID,
		fileID,
		contentType,
		reader,
	)
	if err != nil {
		log.Printf("GCS upload failed for %s: %v", safeFileName, err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "upload_failed",
			"message": "failed to upload file to storage",
		})
		return models.MediaFile{}, err
	}
	log.Printf("File uploaded successfully to %s", objectPath)

	// Generate signed URL
	signedURL, err := h.gcs.GetSignedURL(c.Request.Context(), objectPath, 0)
	if err != nil {
		signedURL = "" // URL will be generated on demand
	}

	return models.MediaFile{
		ID:          fileID,
		FileName:    safeFileName,
		ContentType: contentType,
		Size:        size,
		URL:         signedURL,
		UploadedAt:  time.Now(),
	}, nil
}

// isYouTubeURL checks if a URL is a YouTube URL
func isYouTubeURL(url string) bool {
	return strings.Contains(url, "youtube.com") || strings.Contains(url, "youtu.be")
}

// ListReports handles GET /v1/reports
func (h *ReportsHandler) ListReports(c *gin.Context) {
	user := middleware.RequireUser(c)
	if user == nil {
		return
	}

	reports, err := h.storage.ListReportsByUser(c.Request.Context(), user.Subject)
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

	// Refresh signed URLs for GCS media files (skip YouTube URLs)
	for i := range reports {
		for j := range reports[i].MediaFiles {
			// Skip YouTube URLs - they don't need signed URLs
			if isYouTubeURL(reports[i].MediaFiles[j].URL) {
				continue
			}

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

	report, err := h.storage.GetReportByIDAndUser(c.Request.Context(), reportID, user.Subject)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error":   "not_found",
			"message": "report not found",
		})
		return
	}

	// Refresh signed URLs for GCS media files (skip YouTube URLs)
	for i := range report.MediaFiles {
		// Skip YouTube URLs - they don't need signed URLs
		if isYouTubeURL(report.MediaFiles[i].URL) {
			continue
		}

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
	if err := h.storage.DeleteReport(c.Request.Context(), reportID, user.Subject); err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error":   "not_found",
			"message": "report not found",
		})
		return
	}

	// Note: We don't delete files from GCS/YouTube immediately for soft delete
	// A separate cleanup job could handle permanent deletions

	c.JSON(http.StatusOK, gin.H{
		"message": "report deleted successfully",
	})
}

// ============================================================================
// Public Endpoints (no auth required)
// ============================================================================

// ListApprovedReports handles GET /v1/public/reports
// Returns all approved reports for the public feed (no auth required)
func (h *ReportsHandler) ListApprovedReports(c *gin.Context) {
	reports, err := h.storage.ListApprovedReports(c.Request.Context())
	if err != nil {
		log.Printf("Failed to list approved reports: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "fetch_failed",
			"message": "failed to fetch reports",
		})
		return
	}

	// Refresh signed URLs for GCS media files (skip YouTube URLs)
	for i := range reports {
		for j := range reports[i].MediaFiles {
			if isYouTubeURL(reports[i].MediaFiles[j].URL) {
				continue
			}
			objectPath := fmt.Sprintf("users/%s/reports/%s/%s",
				reports[i].UserID,
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

// ============================================================================
// Admin Endpoints
// ============================================================================

// ListAllReportsAdmin handles GET /v1/admin/reports
// Returns all non-deleted reports for admin dashboard
func (h *ReportsHandler) ListAllReportsAdmin(c *gin.Context) {
	user := middleware.RequireUser(c)
	if user == nil {
		return
	}

	reports, err := h.storage.ListAllReports(c.Request.Context())
	if err != nil {
		log.Printf("Failed to list all reports (admin): %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "fetch_failed",
			"message": "failed to fetch reports",
		})
		return
	}

	c.JSON(http.StatusOK, models.ListReportsResponse{
		Reports: reports,
		Count:   len(reports),
	})
}

// ListReportsForReview handles GET /v1/admin/reports/review
// Returns reports awaiting admin review (status = "submitted")
func (h *ReportsHandler) ListReportsForReview(c *gin.Context) {
	user := middleware.RequireUser(c)
	if user == nil {
		return
	}

	reports, err := h.storage.ListReportsAwaitingReview(c.Request.Context())
	if err != nil {
		log.Printf("Failed to list reports for review: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "fetch_failed",
			"message": "failed to fetch reports",
		})
		return
	}

	// Refresh signed URLs for GCS media files
	for i := range reports {
		for j := range reports[i].MediaFiles {
			if isYouTubeURL(reports[i].MediaFiles[j].URL) {
				continue
			}
			objectPath := fmt.Sprintf("users/%s/reports/%s/%s",
				reports[i].UserID,
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

// ReviewReportRequest represents the request body for reviewing a report
type ReviewReportRequest struct {
	Status   string `json:"status" binding:"required,oneof=reviewed_pass reviewed_fail"`
	Reason   string `json:"reason"`
	Priority *int   `json:"priority"` // 1-5, only used when approving (1=highest priority)
}

// ReviewReport handles POST /v1/admin/reports/:id/review
// Approves or rejects a report
func (h *ReportsHandler) ReviewReport(c *gin.Context) {
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

	var req ReviewReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": err.Error(),
		})
		return
	}

	// Validate that rejected reports have a reason
	if req.Status == models.StatusReviewedFail && req.Reason == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "reason is required when rejecting a report",
		})
		return
	}

	// Use UpdateReportStatusWithPriority when approving with priority
	var err error
	if req.Status == models.StatusReviewedPass && req.Priority != nil {
		err = h.storage.UpdateReportStatusWithPriority(c.Request.Context(), reportID, req.Status, req.Reason, req.Priority)
	} else {
		err = h.storage.UpdateReportStatus(c.Request.Context(), reportID, req.Status, req.Reason)
	}

	if err != nil {
		if err.Error() == "report not found" {
			c.JSON(http.StatusNotFound, gin.H{
				"error":   "not_found",
				"message": "report not found",
			})
			return
		}
		log.Printf("Failed to update report status: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "update_failed",
			"message": "failed to update report status",
		})
		return
	}

	log.Printf("Report %s reviewed by %s: status=%s, priority=%v", reportID, user.Email, req.Status, req.Priority)

	c.JSON(http.StatusOK, gin.H{
		"message":  "report reviewed successfully",
		"status":   req.Status,
		"priority": req.Priority,
	})
}

// ============================================================================
// Reaction Endpoints
// ============================================================================

// AddReaction handles POST /v1/reports/:id/reactions
// Adds a reaction to a report (requires auth)
func (h *ReportsHandler) AddReaction(c *gin.Context) {
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

	var req models.AddReactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": err.Error(),
		})
		return
	}

	// Validate reaction type
	validReactions := map[string]bool{
		models.ReactionThumbsUp:        true,
		models.ReactionThumbsDown:      true,
		models.ReactionAngryCar:        true,
		models.ReactionAngryPedestrian: true,
		models.ReactionAngryBicycle:    true,
	}
	if !validReactions[req.ReactionType] {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "invalid reaction type",
		})
		return
	}

	// Get user email from stored user info
	storedUser, err := h.storage.GetUserByID(c.Request.Context(), user.Subject)
	userEmail := user.Email
	if err == nil && storedUser != nil {
		userEmail = storedUser.Email
	}

	reaction := &models.Reaction{
		ID:           uuid.New().String(),
		ReportID:     reportID,
		UserID:       user.Subject,
		UserEmail:    userEmail,
		ReactionType: req.ReactionType,
		CreatedAt:    time.Now(),
	}

	if err := h.storage.AddReaction(c.Request.Context(), reaction); err != nil {
		log.Printf("Failed to add reaction: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "create_failed",
			"message": "failed to add reaction",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message":      "reaction added",
		"reactionType": req.ReactionType,
	})
}

// RemoveReaction handles DELETE /v1/reports/:id/reactions/:type
// Removes a reaction from a report (requires auth)
func (h *ReportsHandler) RemoveReaction(c *gin.Context) {
	user := middleware.RequireUser(c)
	if user == nil {
		return
	}

	reportID := c.Param("id")
	reactionType := c.Param("type")

	if !validation.ValidateUUID(reportID) {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "invalid report ID format",
		})
		return
	}

	if err := h.storage.RemoveReaction(c.Request.Context(), reportID, user.Subject, reactionType); err != nil {
		log.Printf("Failed to remove reaction: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "delete_failed",
			"message": "failed to remove reaction",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "reaction removed",
	})
}

// GetReportEngagement handles GET /v1/reports/:id/engagement
// Gets reactions and comment count for a report (public, but user reactions require auth)
func (h *ReportsHandler) GetReportEngagement(c *gin.Context) {
	reportID := c.Param("id")
	if !validation.ValidateUUID(reportID) {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "invalid report ID format",
		})
		return
	}

	// Check for optional auth
	userID := ""
	if user, ok := middleware.GetUserFromContext(c); ok && user != nil {
		userID = user.Subject
	}

	engagement, err := h.storage.GetReportEngagement(c.Request.Context(), reportID, userID)
	if err != nil {
		log.Printf("Failed to get engagement: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "fetch_failed",
			"message": "failed to get engagement data",
		})
		return
	}

	c.JSON(http.StatusOK, engagement)
}

// GetBulkEngagement handles POST /v1/reports/engagement
// Gets engagement data for multiple reports efficiently
func (h *ReportsHandler) GetBulkEngagement(c *gin.Context) {
	var req struct {
		ReportIDs []string `json:"reportIds" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": err.Error(),
		})
		return
	}

	// Validate all report IDs
	for _, id := range req.ReportIDs {
		if !validation.ValidateUUID(id) {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "validation_error",
				"message": "invalid report ID format",
			})
			return
		}
	}

	// Check for optional auth
	userID := ""
	if user, ok := middleware.GetUserFromContext(c); ok && user != nil {
		userID = user.Subject
	}

	engagements, err := h.storage.GetBulkReportEngagement(c.Request.Context(), req.ReportIDs, userID)
	if err != nil {
		log.Printf("Failed to get bulk engagement: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "fetch_failed",
			"message": "failed to get engagement data",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"engagements": engagements,
	})
}

// ============================================================================
// Comment Endpoints
// ============================================================================

// AddComment handles POST /v1/reports/:id/comments
// Adds a comment to a report (requires auth)
func (h *ReportsHandler) AddComment(c *gin.Context) {
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

	var req models.AddCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": err.Error(),
		})
		return
	}

	// Get user email from stored user info
	storedUser, err := h.storage.GetUserByID(c.Request.Context(), user.Subject)
	userEmail := user.Email
	if err == nil && storedUser != nil {
		userEmail = storedUser.Email
	}

	now := time.Now()
	comment := &models.Comment{
		ID:        uuid.New().String(),
		ReportID:  reportID,
		UserID:    user.Subject,
		UserEmail: userEmail,
		Content:   req.Content,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := h.storage.AddComment(c.Request.Context(), comment); err != nil {
		log.Printf("Failed to add comment: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "create_failed",
			"message": "failed to add comment",
		})
		return
	}

	c.JSON(http.StatusCreated, comment)
}

// GetComments handles GET /v1/reports/:id/comments
// Gets all comments for a report (public)
func (h *ReportsHandler) GetComments(c *gin.Context) {
	reportID := c.Param("id")
	if !validation.ValidateUUID(reportID) {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "invalid report ID format",
		})
		return
	}

	comments, err := h.storage.GetComments(c.Request.Context(), reportID)
	if err != nil {
		log.Printf("Failed to get comments: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "fetch_failed",
			"message": "failed to get comments",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"comments": comments,
		"count":    len(comments),
	})
}

// DeleteComment handles DELETE /v1/reports/:id/comments/:commentId
// Deletes a comment (requires auth, only owner can delete)
func (h *ReportsHandler) DeleteComment(c *gin.Context) {
	user := middleware.RequireUser(c)
	if user == nil {
		return
	}

	commentID := c.Param("commentId")
	if !validation.ValidateUUID(commentID) {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "invalid comment ID format",
		})
		return
	}

	if err := h.storage.DeleteComment(c.Request.Context(), commentID, user.Subject); err != nil {
		if err.Error() == "comment not found or not authorized" {
			c.JSON(http.StatusNotFound, gin.H{
				"error":   "not_found",
				"message": "comment not found or not authorized to delete",
			})
			return
		}
		log.Printf("Failed to delete comment: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "delete_failed",
			"message": "failed to delete comment",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "comment deleted",
	})
}
