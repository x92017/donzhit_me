package models

import "time"

// UserRole represents the role of a user in the system
type UserRole string

const (
	RoleViewer      UserRole = "viewer"
	RoleContributor UserRole = "contributor"
	RoleAdmin       UserRole = "admin"
)

// User represents an authenticated user in the system
type User struct {
	ID              string     `json:"id"`                        // Google subject ID
	Email           string     `json:"email"`
	Role            UserRole   `json:"role"`
	JWTRefreshToken string     `json:"-"`                         // Not exposed in JSON responses
	CreatedAt       time.Time  `json:"createdAt"`
	UpdatedAt       time.Time  `json:"updatedAt"`
	LastLoginAt     *time.Time `json:"lastLoginAt,omitempty"`
}

// CanAccess checks if the user has the required role or higher
func (u *User) CanAccess(requiredRole UserRole) bool {
	roleHierarchy := map[UserRole]int{
		RoleViewer:      0,
		RoleContributor: 1,
		RoleAdmin:       2,
	}
	return roleHierarchy[u.Role] >= roleHierarchy[requiredRole]
}

// IsAdmin checks if the user has admin role
func (u *User) IsAdmin() bool {
	return u.Role == RoleAdmin
}

// IsContributor checks if the user has contributor role or higher
func (u *User) IsContributor() bool {
	return u.Role == RoleContributor || u.Role == RoleAdmin
}

// AuthResponse represents the response from the login endpoint
type AuthResponse struct {
	Token     string `json:"token"`
	ExpiresAt int64  `json:"expiresAt"` // Unix timestamp
	User      User   `json:"user"`
}

// LoginRequest represents the request body for login
type LoginRequest struct {
	GoogleToken string `json:"googleToken" binding:"required"`
}
