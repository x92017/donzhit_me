package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"traffic_watch_backend/internal/auth"
	"traffic_watch_backend/internal/handlers"
	"traffic_watch_backend/internal/middleware"
	"traffic_watch_backend/internal/storage"
	"traffic_watch_backend/internal/validation"
)

const (
	version = "1.0.0"
)

func main() {
	// Get configuration from environment
	port := getEnv("PORT", "8080")
	projectID := getEnv("GOOGLE_CLOUD_PROJECT", "")
	bucketName := getEnv("GCS_BUCKET", "traffic-watch-media")
	iapAudience := getEnv("IAP_AUDIENCE", "")
	oauthClientID := getEnv("OAUTH_CLIENT_ID", "")
	devMode := getEnv("DEV_MODE", "false") == "true"

	// Set Gin mode
	if devMode {
		gin.SetMode(gin.DebugMode)
	} else {
		gin.SetMode(gin.ReleaseMode)
	}

	ctx := context.Background()

	// Register custom validators
	if err := validation.RegisterCustomValidators(); err != nil {
		log.Fatalf("Failed to register validators: %v", err)
	}

	// Initialize IAP validator (supports both IAP and Google Sign-In tokens)
	iapValidator := auth.NewIAPValidator(iapAudience, devMode)
	if oauthClientID != "" {
		iapValidator.SetOAuthClientID(oauthClientID)
		log.Printf("OAuth client ID configured for Google Sign-In token validation")
	}

	// Initialize storage clients
	var firestoreClient *storage.FirestoreClient
	var gcsClient *storage.GCSClient
	var err error

	// Always initialize storage if project ID is set
	if projectID != "" {
		firestoreClient, err = storage.NewFirestoreClient(ctx, projectID)
		if err != nil {
			log.Fatalf("Failed to create Firestore client: %v", err)
		}
		defer firestoreClient.Close()

		gcsClient, err = storage.NewGCSClient(ctx, bucketName)
		if err != nil {
			log.Fatalf("Failed to create GCS client: %v", err)
		}
		defer gcsClient.Close()

		log.Printf("Storage clients initialized (project: %s, bucket: %s)", projectID, bucketName)
	} else {
		log.Println("WARNING: GOOGLE_CLOUD_PROJECT not set - storage clients not initialized")
	}

	// Initialize handlers
	healthHandler := handlers.NewHealthHandler(version)
	reportsHandler := handlers.NewReportsHandler(firestoreClient, gcsClient)

	// Create Gin router
	router := gin.New()

	// Global middleware
	router.Use(gin.Recovery())
	router.Use(gin.Logger())
	router.Use(middleware.CORS(middleware.DefaultCORSConfig()))

	// API v1 routes
	v1 := router.Group("/v1")
	{
		// Health check (no auth required)
		v1.GET("/health", healthHandler.Health)

		// Protected routes
		protected := v1.Group("")
		protected.Use(middleware.IAPAuth(iapValidator))
		{
			// Reports endpoints
			protected.POST("/reports", reportsHandler.CreateReport)
			protected.GET("/reports", reportsHandler.ListReports)
			protected.GET("/reports/:id", reportsHandler.GetReport)
			protected.DELETE("/reports/:id", reportsHandler.DeleteReport)
		}
	}

	// Create HTTP server
	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("Starting server on port %s (version %s, dev mode: %v)", port, version, devMode)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal for graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	// Give outstanding requests 30 seconds to complete
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}

// getEnv gets an environment variable with a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
