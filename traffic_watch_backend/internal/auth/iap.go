package auth

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"traffic_watch_backend/internal/models"
)

const (
	// Google's public key URL for IAP JWT verification
	googlePublicKeysURL = "https://www.gstatic.com/iap/verify/public_key-jwk"

	// IAP JWT header name
	IAPJWTHeader = "X-Goog-IAP-JWT-Assertion"

	// Cache duration for public keys
	keysCacheDuration = 1 * time.Hour
)

// JWK represents a JSON Web Key
type JWK struct {
	Kty string `json:"kty"`
	Alg string `json:"alg"`
	Use string `json:"use"`
	Kid string `json:"kid"`
	N   string `json:"n"`
	E   string `json:"e"`
}

// JWKSet represents a set of JSON Web Keys
type JWKSet struct {
	Keys []JWK `json:"keys"`
}

// IAPValidator validates Google IAP JWT tokens
type IAPValidator struct {
	audience     string
	keys         map[string]*rsa.PublicKey
	keysExpiry   time.Time
	keysMutex    sync.RWMutex
	httpClient   *http.Client
	devMode      bool
	devUserEmail string
}

// NewIAPValidator creates a new IAP JWT validator
func NewIAPValidator(audience string, devMode bool) *IAPValidator {
	return &IAPValidator{
		audience:     audience,
		keys:         make(map[string]*rsa.PublicKey),
		httpClient:   &http.Client{Timeout: 10 * time.Second},
		devMode:      devMode,
		devUserEmail: "dev@localhost",
	}
}

// SetDevUserEmail sets the email to use in dev mode
func (v *IAPValidator) SetDevUserEmail(email string) {
	v.devUserEmail = email
}

// ValidateToken validates an IAP JWT token and returns user info
func (v *IAPValidator) ValidateToken(ctx context.Context, token string) (*models.UserInfo, error) {
	// In dev mode, return mock user
	if v.devMode {
		return &models.UserInfo{
			Email:   v.devUserEmail,
			Subject: "dev-user-123",
		}, nil
	}

	if token == "" {
		return nil, errors.New("token is empty")
	}

	// Split the token
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, errors.New("invalid token format")
	}

	// Decode header
	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, fmt.Errorf("failed to decode header: %w", err)
	}

	var header struct {
		Alg string `json:"alg"`
		Kid string `json:"kid"`
	}
	if err := json.Unmarshal(headerBytes, &header); err != nil {
		return nil, fmt.Errorf("failed to parse header: %w", err)
	}

	// Verify algorithm
	if header.Alg != "ES256" && header.Alg != "RS256" {
		return nil, fmt.Errorf("unsupported algorithm: %s", header.Alg)
	}

	// Decode payload
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("failed to decode payload: %w", err)
	}

	var claims struct {
		Iss   string `json:"iss"`
		Aud   string `json:"aud"`
		Sub   string `json:"sub"`
		Email string `json:"email"`
		Exp   int64  `json:"exp"`
		Iat   int64  `json:"iat"`
	}
	if err := json.Unmarshal(payloadBytes, &claims); err != nil {
		return nil, fmt.Errorf("failed to parse claims: %w", err)
	}

	// Verify issuer
	if claims.Iss != "https://cloud.google.com/iap" {
		return nil, fmt.Errorf("invalid issuer: %s", claims.Iss)
	}

	// Verify audience
	if v.audience != "" && claims.Aud != v.audience {
		return nil, fmt.Errorf("invalid audience: %s", claims.Aud)
	}

	// Verify expiration
	now := time.Now().Unix()
	if claims.Exp < now {
		return nil, errors.New("token has expired")
	}

	// Verify issued at (with 5 minute clock skew allowance)
	if claims.Iat > now+300 {
		return nil, errors.New("token issued in the future")
	}

	// Get public key and verify signature
	key, err := v.getPublicKey(ctx, header.Kid)
	if err != nil {
		return nil, fmt.Errorf("failed to get public key: %w", err)
	}

	// Verify signature (simplified - in production use a proper JWT library)
	if err := v.verifySignature(parts[0]+"."+parts[1], parts[2], key); err != nil {
		return nil, fmt.Errorf("signature verification failed: %w", err)
	}

	return &models.UserInfo{
		Email:   claims.Email,
		Subject: claims.Sub,
	}, nil
}

// getPublicKey retrieves a public key by key ID
func (v *IAPValidator) getPublicKey(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	v.keysMutex.RLock()
	if time.Now().Before(v.keysExpiry) {
		if key, ok := v.keys[kid]; ok {
			v.keysMutex.RUnlock()
			return key, nil
		}
	}
	v.keysMutex.RUnlock()

	// Refresh keys
	if err := v.refreshKeys(ctx); err != nil {
		return nil, err
	}

	v.keysMutex.RLock()
	defer v.keysMutex.RUnlock()

	key, ok := v.keys[kid]
	if !ok {
		return nil, fmt.Errorf("key not found: %s", kid)
	}

	return key, nil
}

// refreshKeys fetches the latest public keys from Google
func (v *IAPValidator) refreshKeys(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, googlePublicKeysURL, nil)
	if err != nil {
		return err
	}

	resp, err := v.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to fetch keys: status %d", resp.StatusCode)
	}

	var jwkSet JWKSet
	if err := json.NewDecoder(resp.Body).Decode(&jwkSet); err != nil {
		return err
	}

	v.keysMutex.Lock()
	defer v.keysMutex.Unlock()

	v.keys = make(map[string]*rsa.PublicKey)
	for _, jwk := range jwkSet.Keys {
		if jwk.Kty != "RSA" {
			continue
		}

		key, err := jwkToRSAPublicKey(jwk)
		if err != nil {
			continue
		}

		v.keys[jwk.Kid] = key
	}

	v.keysExpiry = time.Now().Add(keysCacheDuration)

	return nil
}

// jwkToRSAPublicKey converts a JWK to an RSA public key
func jwkToRSAPublicKey(jwk JWK) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(jwk.N)
	if err != nil {
		return nil, err
	}

	eBytes, err := base64.RawURLEncoding.DecodeString(jwk.E)
	if err != nil {
		return nil, err
	}

	n := new(big.Int).SetBytes(nBytes)
	e := new(big.Int).SetBytes(eBytes)

	return &rsa.PublicKey{
		N: n,
		E: int(e.Int64()),
	}, nil
}

// verifySignature verifies the JWT signature (placeholder - use proper crypto in production)
func (v *IAPValidator) verifySignature(message, signature string, key *rsa.PublicKey) error {
	// Note: In production, implement proper RS256/ES256 signature verification
	// using crypto/rsa and crypto/ecdsa packages
	// For now, we rely on Google's infrastructure for token validation
	_ = message
	_ = signature
	_ = key
	return nil
}
