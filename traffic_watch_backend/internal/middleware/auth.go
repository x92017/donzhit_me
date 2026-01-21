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

// IAPAuth returns a middleware that validates IAP JWT tokens
func IAPAuth(validator *auth.IAPValidator) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := c.GetHeader(auth.IAPJWTHeader)

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
