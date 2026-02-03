package auth

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"donzhit_me_backend/internal/models"
)

const (
	// TokenExpiry is 1 year for long-lived tokens
	TokenExpiry = 365 * 24 * time.Hour
)

// JWTClaims represents the custom claims in the JWT
type JWTClaims struct {
	UserID       string          `json:"user_id"`
	Email        string          `json:"email"`
	Role         models.UserRole `json:"role"`
	RefreshToken string          `json:"refresh_token"` // For invalidation
	jwt.RegisteredClaims
}

// JWTService handles JWT operations
type JWTService struct {
	secretKey []byte
	issuer    string
}

// NewJWTService creates a new JWT service
func NewJWTService(secretKey string, issuer string) *JWTService {
	return &JWTService{
		secretKey: []byte(secretKey),
		issuer:    issuer,
	}
}

// GenerateToken creates a new JWT for a user
// Returns: token string, refresh token ID, expiry time, error
func (s *JWTService) GenerateToken(user *models.User) (string, string, time.Time, error) {
	// Generate a random refresh token ID for invalidation
	refreshToken, err := generateRandomToken()
	if err != nil {
		return "", "", time.Time{}, err
	}

	expiresAt := time.Now().Add(TokenExpiry)

	claims := JWTClaims{
		UserID:       user.ID,
		Email:        user.Email,
		Role:         user.Role,
		RefreshToken: refreshToken,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    s.issuer,
			Subject:   user.ID,
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signedToken, err := token.SignedString(s.secretKey)
	if err != nil {
		return "", "", time.Time{}, err
	}

	return signedToken, refreshToken, expiresAt, nil
}

// ValidateToken validates a JWT and returns the claims
func (s *JWTService) ValidateToken(tokenString string) (*JWTClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return s.secretKey, nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*JWTClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

// generateRandomToken generates a random hex string for refresh token
func generateRandomToken() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}
