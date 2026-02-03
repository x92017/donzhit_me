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

	"donzhit_me_backend/internal/auth"
	"donzhit_me_backend/internal/handlers"
	"donzhit_me_backend/internal/middleware"
	"donzhit_me_backend/internal/models"
	"donzhit_me_backend/internal/storage"
	"donzhit_me_backend/internal/validation"
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

	// Database configuration
	dbType := getEnv("DB_TYPE", "firestore") // "firestore" or "postgres"
	dbConnectionString := getEnv("DB_CONNECTION_STRING", "")
	cloudSQLInstance := getEnv("CLOUD_SQL_INSTANCE", "")
	dbName := getEnv("DB_NAME", "donzhit")
	dbUser := getEnv("DB_USER", "donzhit_app")
	dbPassword := getEnv("DB_PASSWORD", "")

	// YouTube configuration
	youtubeClientID := getEnv("YOUTUBE_CLIENT_ID", "")
	youtubeClientSecret := getEnv("YOUTUBE_CLIENT_SECRET", "")
	youtubeRefreshToken := getEnv("YOUTUBE_REFRESH_TOKEN", "")

	// JWT configuration
	jwtSecret := getEnv("JWT_SECRET", "change-this-in-production-use-256-bit-key")
	jwtIssuer := getEnv("JWT_ISSUER", "donzhit.me")

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
	var storageClient storage.Client
	var gcsClient *storage.GCSClient
	var youtubeClient *storage.YouTubeClient
	var err error

	// Initialize database storage based on DB_TYPE
	switch dbType {
	case "postgres":
		log.Printf("Initializing PostgreSQL storage backend")
		if dbConnectionString != "" {
			// Use direct connection string (for local development)
			storageClient, err = storage.NewPostgresClientFromConnString(ctx, dbConnectionString)
			if err != nil {
				log.Fatalf("Failed to create PostgreSQL client from connection string: %v", err)
			}
			log.Printf("PostgreSQL client initialized using connection string")
		} else if cloudSQLInstance != "" {
			// Use Cloud SQL connector (for production)
			storageClient, err = storage.NewPostgresClient(ctx, cloudSQLInstance, dbUser, dbPassword, dbName)
			if err != nil {
				log.Fatalf("Failed to create PostgreSQL client via Cloud SQL: %v", err)
			}
			log.Printf("PostgreSQL client initialized via Cloud SQL connector (instance: %s)", cloudSQLInstance)
		} else {
			log.Fatalf("DB_TYPE=postgres requires either DB_CONNECTION_STRING or CLOUD_SQL_INSTANCE to be set")
		}

	case "firestore":
		fallthrough
	default:
		if dbType != "firestore" {
			log.Printf("WARNING: Unknown DB_TYPE '%s', falling back to Firestore", dbType)
		}
		log.Printf("Initializing Firestore storage backend")
		if projectID == "" {
			log.Fatalf("GOOGLE_CLOUD_PROJECT is required for Firestore backend")
		}
		firestoreClient, err := storage.NewFirestoreClient(ctx, projectID)
		if err != nil {
			log.Fatalf("Failed to create Firestore client: %v", err)
		}
		storageClient = firestoreClient
		log.Printf("Firestore client initialized (project: %s)", projectID)
	}
	defer storageClient.Close()

	// Initialize GCS client (needed for image storage)
	if bucketName != "" {
		gcsClient, err = storage.NewGCSClient(ctx, bucketName)
		if err != nil {
			log.Fatalf("Failed to create GCS client: %v", err)
		}
		defer gcsClient.Close()
		log.Printf("GCS client initialized (bucket: %s)", bucketName)
	} else {
		log.Println("WARNING: GCS_BUCKET not set - image uploads will not work")
	}

	// Initialize YouTube client (for video uploads)
	if youtubeClientID != "" && youtubeClientSecret != "" && youtubeRefreshToken != "" {
		youtubeClient, err = storage.NewYouTubeClient(ctx, youtubeClientID, youtubeClientSecret, youtubeRefreshToken)
		if err != nil {
			log.Printf("WARNING: Failed to create YouTube client: %v - video uploads will fall back to GCS", err)
		} else {
			log.Printf("YouTube client initialized for video uploads")
		}
	} else {
		log.Println("WARNING: YouTube credentials not configured - video uploads will use GCS")
	}

	// Initialize JWT service
	jwtService := auth.NewJWTService(jwtSecret, jwtIssuer)
	log.Printf("JWT service initialized (issuer: %s)", jwtIssuer)

	// Initialize handlers
	healthHandler := handlers.NewHealthHandler(version)
	reportsHandler := handlers.NewReportsHandler(storageClient, gcsClient, youtubeClient)
	authHandler := handlers.NewAuthHandler(storageClient, iapValidator, jwtService)

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

		// Public endpoints (no auth required)
		publicGroup := v1.Group("/public")
		{
			publicGroup.GET("/reports", reportsHandler.ListApprovedReports)
		}

		// Auth endpoints (login requires Google token, not JWT)
		authGroup := v1.Group("/auth")
		{
			authGroup.POST("/login", authHandler.Login)
		}

		// Protected auth endpoints (requires JWT)
		authProtected := v1.Group("/auth")
		authProtected.Use(middleware.JWTAuth(jwtService, storageClient))
		{
			authProtected.GET("/me", authHandler.GetCurrentUser)
			authProtected.POST("/logout", authHandler.Logout)
		}

		// Protected routes with JWT auth (for new JWT-based clients)
		jwtProtected := v1.Group("")
		jwtProtected.Use(middleware.JWTAuth(jwtService, storageClient))
		jwtProtected.Use(middleware.RequireRole(models.RoleContributor))
		{
			// Reports endpoints
			jwtProtected.POST("/reports", reportsHandler.CreateReport)
			jwtProtected.GET("/reports", reportsHandler.ListReports)
			jwtProtected.GET("/reports/:id", reportsHandler.GetReport)
			jwtProtected.DELETE("/reports/:id", reportsHandler.DeleteReport)
		}

		// Admin routes (requires JWT + admin role)
		adminGroup := v1.Group("/admin")
		adminGroup.Use(middleware.JWTAuth(jwtService, storageClient))
		adminGroup.Use(middleware.RequireRole(models.RoleAdmin))
		{
			adminGroup.GET("/reports", reportsHandler.ListAllReportsAdmin)
			adminGroup.GET("/reports/review", reportsHandler.ListReportsForReview)
			adminGroup.POST("/reports/:id/review", reportsHandler.ReviewReport)
		}

		// Legacy protected routes with Google token auth (for backwards compatibility)
		// TODO: Remove after all clients migrate to JWT
		legacyProtected := v1.Group("/legacy")
		legacyProtected.Use(middleware.IAPAuth(iapValidator))
		{
			legacyProtected.POST("/reports", reportsHandler.CreateReport)
			legacyProtected.GET("/reports", reportsHandler.ListReports)
			legacyProtected.GET("/reports/:id", reportsHandler.GetReport)
			legacyProtected.DELETE("/reports/:id", reportsHandler.DeleteReport)
		}
	}

	// Create HTTP server
	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 300 * time.Second, // Increased for video uploads
		IdleTimeout:  120 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("Starting server on port %s (version %s, dev mode: %v, db: %s)", port, version, devMode, dbType)
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
