package handlers

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"donzhit_me_backend/internal/auth"
	"donzhit_me_backend/internal/models"
	"donzhit_me_backend/internal/storage"
)

const adminEmail = "jeffarbaugh@gmail.com"

// AuthHandler handles authentication endpoints
type AuthHandler struct {
	storage      storage.Client
	iapValidator *auth.IAPValidator
	jwtService   *auth.JWTService
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler(storage storage.Client, iapValidator *auth.IAPValidator, jwtService *auth.JWTService) *AuthHandler {
	return &AuthHandler{
		storage:      storage,
		iapValidator: iapValidator,
		jwtService:   jwtService,
	}
}

// Login handles POST /v1/auth/login
// Exchanges a Google token for a DonzHit.me JWT
func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "validation_error",
			"message": "googleToken is required",
		})
		return
	}

	log.Printf("Login attempt with Google token (length: %d)", len(req.GoogleToken))

	// Validate the Google token
	userInfo, err := h.iapValidator.ValidateToken(c.Request.Context(), req.GoogleToken)
	if err != nil {
		log.Printf("Google token validation failed: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{
			"error":   "invalid_token",
			"message": "Invalid Google token",
		})
		return
	}

	log.Printf("Google token validated for user: %s (subject: %s)", userInfo.Email, userInfo.Subject)

	// Check if user exists
	user, err := h.storage.GetUserByID(c.Request.Context(), userInfo.Subject)
	if err != nil {
		// New user - determine role
		role := models.RoleContributor
		if userInfo.Email == adminEmail {
			role = models.RoleAdmin
		}

		user = &models.User{
			ID:    userInfo.Subject,
			Email: userInfo.Email,
			Role:  role,
		}
		log.Printf("Creating new user: %s with role: %s", userInfo.Email, role)
	} else {
		log.Printf("Existing user found: %s with role: %s", user.Email, user.Role)
		// Existing user - ensure admin email always has admin role
		if userInfo.Email == adminEmail && user.Role != models.RoleAdmin {
			user.Role = models.RoleAdmin
			log.Printf("Upgrading user %s to admin role", userInfo.Email)
		}
	}

	// Generate JWT
	token, refreshToken, expiresAt, err := h.jwtService.GenerateToken(user)
	if err != nil {
		log.Printf("Failed to generate JWT: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "token_generation_failed",
			"message": "Failed to generate token",
		})
		return
	}

	// Store refresh token in user record
	user.JWTRefreshToken = refreshToken

	// Create or update user
	if err := h.storage.CreateOrUpdateUser(c.Request.Context(), user); err != nil {
		log.Printf("Failed to create/update user: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "user_creation_failed",
			"message": "Failed to create/update user",
		})
		return
	}

	// Update last login
	h.storage.UpdateUserLastLogin(c.Request.Context(), user.ID)

	log.Printf("Login successful for user: %s, token expires: %v", user.Email, expiresAt)

	c.JSON(http.StatusOK, models.AuthResponse{
		Token:     token,
		ExpiresAt: expiresAt.Unix(),
		User:      *user,
	})
}

// GetCurrentUser handles GET /v1/auth/me
func (h *AuthHandler) GetCurrentUser(c *gin.Context) {
	user, exists := c.Get("user")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error":   "unauthorized",
			"message": "Not authenticated",
		})
		return
	}
	c.JSON(http.StatusOK, user)
}

// Logout handles POST /v1/auth/logout
// Revokes the current token
func (h *AuthHandler) Logout(c *gin.Context) {
	user, exists := c.Get("user")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error":   "unauthorized",
			"message": "Not authenticated",
		})
		return
	}

	u := user.(*models.User)
	if err := h.storage.RevokeUserToken(c.Request.Context(), u.ID); err != nil {
		log.Printf("Failed to revoke token for user %s: %v", u.Email, err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "logout_failed",
			"message": "Failed to logout",
		})
		return
	}

	log.Printf("User logged out: %s", u.Email)

	c.JSON(http.StatusOK, gin.H{
		"message": "Logged out successfully",
	})
}
