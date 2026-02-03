package models

import (
	"time"
)

// MediaFile represents an uploaded media file (image or video)
type MediaFile struct {
	ID          string `json:"id" firestore:"id"`
	FileName    string `json:"fileName" firestore:"fileName"`
	ContentType string `json:"contentType" firestore:"contentType"`
	Size        int64  `json:"size" firestore:"size"`
	URL         string `json:"url" firestore:"url"`
	UploadedAt  time.Time `json:"uploadedAt" firestore:"uploadedAt"`
}

// TrafficReport represents a traffic incident report
type TrafficReport struct {
	ID          string      `json:"id" firestore:"id"`
	UserID      string      `json:"userId" firestore:"userId"`
	Title       string      `json:"title" binding:"required,min=1,max=200" firestore:"title"`
	Description string      `json:"description" binding:"required,min=1,max=5000" firestore:"description"`
	DateTime    time.Time   `json:"dateTime" binding:"required" firestore:"dateTime"`
	RoadUsages  []string    `json:"roadUsages" firestore:"roadUsages"`
	EventTypes  []string    `json:"eventTypes" firestore:"eventTypes"`
	State       string      `json:"state" binding:"required,stateorprovince" firestore:"state"`
	City        string      `json:"city" firestore:"city"`
	Injuries    string      `json:"injuries" binding:"max=1000" firestore:"injuries"`
	MediaFiles   []MediaFile `json:"mediaFiles" firestore:"mediaFiles"`
	CreatedAt    time.Time   `json:"createdAt" firestore:"createdAt"`
	UpdatedAt    time.Time   `json:"updatedAt" firestore:"updatedAt"`
	Status       string      `json:"status" firestore:"status"`
	ReviewReason string      `json:"reviewReason,omitempty" firestore:"review_reason"`
	Priority     *int        `json:"priority,omitempty" firestore:"priority"`
}

// ReportStatus constants
const (
	StatusSubmitted    = "submitted"      // New report awaiting review
	StatusReviewedPass = "reviewed_pass"  // Admin approved
	StatusReviewedFail = "reviewed_fail"  // Admin rejected
	StatusDeleted      = "deleted"        // Soft deleted
)

// CreateReportRequest represents the request body for creating a report
type CreateReportRequest struct {
	Title       string    `json:"title" binding:"required,min=1,max=200"`
	Description string    `json:"description" binding:"required,min=1,max=5000"`
	DateTime    time.Time `json:"dateTime" binding:"required"`
	RoadUsages  []string  `json:"roadUsages"`
	EventTypes  []string  `json:"eventTypes"`
	State       string    `json:"state" binding:"required,stateorprovince"`
	City        string    `json:"city"`
	Injuries    string    `json:"injuries" binding:"max=1000"`
}

// ListReportsResponse represents the response for listing reports
type ListReportsResponse struct {
	Reports []TrafficReport `json:"reports"`
	Count   int             `json:"count"`
}

// UserInfo represents authenticated user information from IAP JWT
type UserInfo struct {
	Email   string `json:"email"`
	Subject string `json:"sub"`
}
