package middleware

import (
	"net/http"

	"traffic_watch_backend/internal/auth"
	"traffic_watch_backend/internal/models"

	"github.com/gin-gonic/gin"
)

const (
	// UserContextKey is the key used to store user info in the context
	UserContextKey = "user"
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
