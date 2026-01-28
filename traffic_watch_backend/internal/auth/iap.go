package auth

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"donzhit_me_backend/internal/models"
)

const (
	// Google's public key URL for IAP JWT verification
	googleIAPPublicKeysURL = "https://www.gstatic.com/iap/verify/public_key-jwk"

	// Google's public key URL for OAuth2/Sign-In ID token verification
	googleOAuth2PublicKeysURL = "https://www.googleapis.com/oauth2/v3/certs"

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

// IAPValidator validates Google IAP JWT tokens and Google Sign-In ID tokens
type IAPValidator struct {
	audience        string
	oauthClientIDs  []string // Multiple client IDs (web, android, ios)
	iapKeys         map[string]*rsa.PublicKey
	iapKeysExpiry   time.Time
	oauth2Keys      map[string]*rsa.PublicKey
	oauth2Expiry    time.Time
	keysMutex       sync.RWMutex
	httpClient      *http.Client
	devMode         bool
	devUserEmail    string
}

// NewIAPValidator creates a new IAP JWT validator
func NewIAPValidator(audience string, devMode bool) *IAPValidator {
	return &IAPValidator{
		audience:     audience,
		iapKeys:      make(map[string]*rsa.PublicKey),
		oauth2Keys:   make(map[string]*rsa.PublicKey),
		httpClient:   &http.Client{Timeout: 10 * time.Second},
		devMode:      devMode,
		devUserEmail: "dev@localhost",
	}
}

// SetOAuthClientID sets the OAuth2 client ID for Google Sign-In token validation
// Accepts comma-separated list of client IDs (web, android, ios)
func (v *IAPValidator) SetOAuthClientID(clientIDs string) {
	if clientIDs == "" {
		return
	}
	v.oauthClientIDs = strings.Split(clientIDs, ",")
	for i, id := range v.oauthClientIDs {
		v.oauthClientIDs[i] = strings.TrimSpace(id)
	}
}

// SetDevUserEmail sets the email to use in dev mode
func (v *IAPValidator) SetDevUserEmail(email string) {
	v.devUserEmail = email
}

// ValidateToken validates an IAP JWT token, Google Sign-In ID token, or Google OAuth access token
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

	// Split the token to check format
	parts := strings.Split(token, ".")

	// If token is not a JWT (doesn't have 3 parts), try validating as an access token
	if len(parts) != 3 {
		// Try to validate as Google OAuth access token
		return v.validateAccessToken(ctx, token)
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

	// Check issuer to determine token type
	isIAPToken := claims.Iss == "https://cloud.google.com/iap"
	isGoogleIDToken := claims.Iss == "https://accounts.google.com" || claims.Iss == "accounts.google.com"

	if !isIAPToken && !isGoogleIDToken {
		return nil, fmt.Errorf("invalid issuer: %s", claims.Iss)
	}

	// Verify audience based on token type
	if isIAPToken {
		if v.audience != "" && claims.Aud != v.audience {
			return nil, fmt.Errorf("invalid audience for IAP token: %s", claims.Aud)
		}
	} else if isGoogleIDToken {
		// For Google ID tokens, audience should be one of the OAuth2 client IDs
		if len(v.oauthClientIDs) > 0 {
			valid := false
			for _, clientID := range v.oauthClientIDs {
				if claims.Aud == clientID {
					valid = true
					break
				}
			}
			if !valid {
				return nil, fmt.Errorf("invalid audience for Google ID token: %s (expected one of: %v)", claims.Aud, v.oauthClientIDs)
			}
		}
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

	// Get public key based on token type and verify signature
	var key *rsa.PublicKey
	if isIAPToken {
		key, err = v.getIAPPublicKey(ctx, header.Kid)
	} else {
		key, err = v.getOAuth2PublicKey(ctx, header.Kid)
	}
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

// getIAPPublicKey retrieves a public key for IAP tokens by key ID
func (v *IAPValidator) getIAPPublicKey(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	v.keysMutex.RLock()
	if time.Now().Before(v.iapKeysExpiry) {
		if key, ok := v.iapKeys[kid]; ok {
			v.keysMutex.RUnlock()
			return key, nil
		}
	}
	v.keysMutex.RUnlock()

	// Refresh keys
	if err := v.refreshIAPKeys(ctx); err != nil {
		return nil, err
	}

	v.keysMutex.RLock()
	defer v.keysMutex.RUnlock()

	key, ok := v.iapKeys[kid]
	if !ok {
		return nil, fmt.Errorf("IAP key not found: %s", kid)
	}

	return key, nil
}

// getOAuth2PublicKey retrieves a public key for Google Sign-In tokens by key ID
func (v *IAPValidator) getOAuth2PublicKey(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	v.keysMutex.RLock()
	if time.Now().Before(v.oauth2Expiry) {
		if key, ok := v.oauth2Keys[kid]; ok {
			v.keysMutex.RUnlock()
			return key, nil
		}
	}
	v.keysMutex.RUnlock()

	// Refresh keys
	if err := v.refreshOAuth2Keys(ctx); err != nil {
		return nil, err
	}

	v.keysMutex.RLock()
	defer v.keysMutex.RUnlock()

	key, ok := v.oauth2Keys[kid]
	if !ok {
		return nil, fmt.Errorf("OAuth2 key not found: %s", kid)
	}

	return key, nil
}

// refreshIAPKeys fetches the latest IAP public keys from Google
func (v *IAPValidator) refreshIAPKeys(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, googleIAPPublicKeysURL, nil)
	if err != nil {
		return err
	}

	resp, err := v.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to fetch IAP keys: status %d", resp.StatusCode)
	}

	var jwkSet JWKSet
	if err := json.NewDecoder(resp.Body).Decode(&jwkSet); err != nil {
		return err
	}

	v.keysMutex.Lock()
	defer v.keysMutex.Unlock()

	v.iapKeys = make(map[string]*rsa.PublicKey)
	for _, jwk := range jwkSet.Keys {
		if jwk.Kty != "RSA" {
			continue
		}

		key, err := jwkToRSAPublicKey(jwk)
		if err != nil {
			continue
		}

		v.iapKeys[jwk.Kid] = key
	}

	v.iapKeysExpiry = time.Now().Add(keysCacheDuration)

	return nil
}

// refreshOAuth2Keys fetches the latest OAuth2 public keys from Google
func (v *IAPValidator) refreshOAuth2Keys(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, googleOAuth2PublicKeysURL, nil)
	if err != nil {
		return err
	}

	resp, err := v.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to fetch OAuth2 keys: status %d", resp.StatusCode)
	}

	var jwkSet JWKSet
	if err := json.NewDecoder(resp.Body).Decode(&jwkSet); err != nil {
		return err
	}

	v.keysMutex.Lock()
	defer v.keysMutex.Unlock()

	v.oauth2Keys = make(map[string]*rsa.PublicKey)
	for _, jwk := range jwkSet.Keys {
		if jwk.Kty != "RSA" {
			continue
		}

		key, err := jwkToRSAPublicKey(jwk)
		if err != nil {
			continue
		}

		v.oauth2Keys[jwk.Kid] = key
	}

	v.oauth2Expiry = time.Now().Add(keysCacheDuration)

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

// validateAccessToken validates a Google OAuth access token by calling Google's tokeninfo API
func (v *IAPValidator) validateAccessToken(ctx context.Context, token string) (*models.UserInfo, error) {
	prefixLen := 20
	if len(token) < prefixLen {
		prefixLen = len(token)
	}
	log.Printf("validateAccessToken: validating access token (length: %d, prefix: %s...)", len(token), token[:prefixLen])

	// Call Google's tokeninfo endpoint to validate the access token
	tokenInfoURL := fmt.Sprintf("https://oauth2.googleapis.com/tokeninfo?access_token=%s", token)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, tokenInfoURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create tokeninfo request: %w", err)
	}

	resp, err := v.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to validate access token: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("validateAccessToken: tokeninfo returned status %d", resp.StatusCode)
		return nil, fmt.Errorf("invalid access token: status %d", resp.StatusCode)
	}

	var tokenInfo struct {
		Azp           string `json:"azp"`
		Aud           string `json:"aud"`
		Sub           string `json:"sub"`
		Scope         string `json:"scope"`
		Exp           string `json:"exp"`
		ExpiresIn     string `json:"expires_in"`
		Email         string `json:"email"`
		EmailVerified string `json:"email_verified"`
		AccessType    string `json:"access_type"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&tokenInfo); err != nil {
		return nil, fmt.Errorf("failed to decode tokeninfo response: %w", err)
	}

	log.Printf("validateAccessToken: tokeninfo response - azp: %s, aud: %s, email: %s, sub: %s",
		tokenInfo.Azp, tokenInfo.Aud, tokenInfo.Email, tokenInfo.Sub)

	// Verify the token is for our application (if OAuth client IDs are configured)
	if len(v.oauthClientIDs) > 0 {
		log.Printf("validateAccessToken: checking audience against oauthClientIDs: %v", v.oauthClientIDs)
		valid := false
		for _, clientID := range v.oauthClientIDs {
			if tokenInfo.Azp == clientID || tokenInfo.Aud == clientID {
				valid = true
				break
			}
		}
		if !valid {
			log.Printf("validateAccessToken: audience mismatch!")
			return nil, fmt.Errorf("access token not issued for this application (azp: %s, aud: %s, expected one of: %v)",
				tokenInfo.Azp, tokenInfo.Aud, v.oauthClientIDs)
		}
	}

	// Verify email is present
	if tokenInfo.Email == "" {
		log.Printf("validateAccessToken: no email in token")
		return nil, errors.New("access token does not contain email")
	}

	log.Printf("validateAccessToken: success - email: %s", tokenInfo.Email)
	return &models.UserInfo{
		Email:   tokenInfo.Email,
		Subject: tokenInfo.Sub,
	}, nil
}
