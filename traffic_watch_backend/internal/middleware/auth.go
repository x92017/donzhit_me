package middleware

import (
	"log"
	"net/http"
	"strings"

	"donzhit_me_backend/internal/auth"
	"donzhit_me_backend/internal/models"
	"donzhit_me_backend/internal/storage"

	"github.com/gin-gonic/gin"
)

const (
	// UserContextKey is the key used to store UserInfo in the context (for legacy handlers)
	UserContextKey = "userInfo"
	// FullUserContextKey is the key used to store the full User object
	FullUserContextKey = "user"
)

// IAPAuth returns a middleware that validates IAP JWT tokens or Google Sign-In ID tokens
func IAPAuth(validator *auth.IAPValidator) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Try IAP header first
		token := c.GetHeader(auth.IAPJWTHeader)

		// If no IAP header, try Authorization Bearer token
		if token == "" {
			authHeader := c.GetHeader("Authorization")
			if len(authHeader) > 7 && authHeader[:7] == "Bearer " {
				token = authHeader[7:]
			}
		}

		userInfo, err := validator.ValidateToken(c.Request.Context(), token)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "invalid or missing authentication token",
			})
			return
		}

		// Store user info in context
		c.Set(UserContextKey, userInfo)
		c.Next()
	}
}

// GetUserFromContext retrieves the user info from the Gin context
func GetUserFromContext(c *gin.Context) (*models.UserInfo, bool) {
	value, exists := c.Get(UserContextKey)
	if !exists {
		return nil, false
	}

	userInfo, ok := value.(*models.UserInfo)
	return userInfo, ok
}

// RequireUser is a helper that returns the user or aborts with 401
func RequireUser(c *gin.Context) *models.UserInfo {
	userInfo, ok := GetUserFromContext(c)
	if !ok {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
			"error":   "unauthorized",
			"message": "user not authenticated",
		})
		return nil
	}
	return userInfo
}

// JWTAuth middleware validates DonzHit.me JWT tokens
func JWTAuth(jwtService *auth.JWTService, storageClient storage.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "missing authorization header",
			})
			return
		}

		if !strings.HasPrefix(authHeader, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "invalid authorization format",
			})
			return
		}

		token := authHeader[7:]

		claims, err := jwtService.ValidateToken(token)
		if err != nil {
			log.Printf("JWT validation failed: %v", err)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "invalid or expired token",
			})
			return
		}

		// Fetch user to verify refresh token hasn't been revoked
		user, err := storageClient.GetUserByID(c.Request.Context(), claims.UserID)
		if err != nil {
			log.Printf("User not found for JWT: %s", claims.UserID)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "user not found",
			})
			return
		}

		// Check if token has been revoked
		if user.JWTRefreshToken != claims.RefreshToken {
			log.Printf("Token revoked for user: %s", user.Email)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "token has been revoked",
			})
			return
		}

		// Store full user in context
		c.Set("user", user)
		// Also store UserInfo for backwards compatibility with existing handlers
		c.Set(UserContextKey, &models.UserInfo{
			Email:   user.Email,
			Subject: user.ID,
		})

		c.Next()
	}
}

// RequireRole middleware checks if user has required role
func RequireRole(requiredRole models.UserRole) gin.HandlerFunc {
	return func(c *gin.Context) {
		user, exists := c.Get("user")
		if !exists {
			log.Printf("RequireRole: 'user' key not found in context")
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "not authenticated",
			})
			return
		}

		log.Printf("RequireRole: user type = %T, value = %+v", user, user)

		u, ok := user.(*models.User)
		if !ok {
			log.Printf("RequireRole: type assertion to *models.User failed, actual type: %T", user)
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
				"error":   "internal_error",
				"message": "invalid user context",
			})
			return
		}

		if !u.CanAccess(requiredRole) {
			log.Printf("Access denied for user %s (role: %s, required: %s)", u.Email, u.Role, requiredRole)
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error":   "forbidden",
				"message": "insufficient permissions",
			})
			return
		}

		c.Next()
	}
}

// OptionalJWTAuth middleware allows both authenticated and unauthenticated requests
func OptionalJWTAuth(jwtService *auth.JWTService, storageClient storage.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			// No auth - continue as anonymous
			c.Next()
			return
		}

		token := authHeader[7:]
		claims, err := jwtService.ValidateToken(token)
		if err != nil {
			// Invalid token - continue as anonymous
			c.Next()
			return
		}

		user, err := storageClient.GetUserByID(c.Request.Context(), claims.UserID)
		if err != nil || user.JWTRefreshToken != claims.RefreshToken {
			// User not found or token revoked - continue as anonymous
			c.Next()
			return
		}

		c.Set("user", user)
		c.Set(UserContextKey, &models.UserInfo{
			Email:   user.Email,
			Subject: user.ID,
		})
		c.Next()
	}
}
