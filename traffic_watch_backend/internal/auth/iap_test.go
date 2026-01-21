package auth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"testing"
	"time"
)

func TestNewIAPValidator(t *testing.T) {
	tests := []struct {
		name     string
		audience string
		devMode  bool
	}{
		{
			name:     "production mode",
			audience: "/projects/123/apps/myapp",
			devMode:  false,
		},
		{
			name:     "dev mode",
			audience: "",
			devMode:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			validator := NewIAPValidator(tt.audience, tt.devMode)
			if validator == nil {
				t.Error("expected validator to be created")
			}
			if validator.audience != tt.audience {
				t.Errorf("expected audience %q, got %q", tt.audience, validator.audience)
			}
			if validator.devMode != tt.devMode {
				t.Errorf("expected devMode %v, got %v", tt.devMode, validator.devMode)
			}
		})
	}
}

func TestValidateToken_DevMode(t *testing.T) {
	validator := NewIAPValidator("", true)
	validator.SetDevUserEmail("test@example.com")

	ctx := context.Background()
	userInfo, err := validator.ValidateToken(ctx, "any-token")

	if err != nil {
		t.Errorf("expected no error in dev mode, got %v", err)
	}
	if userInfo == nil {
		t.Fatal("expected userInfo in dev mode")
	}
	if userInfo.Email != "test@example.com" {
		t.Errorf("expected email test@example.com, got %q", userInfo.Email)
	}
	if userInfo.Subject != "dev-user-123" {
		t.Errorf("expected subject dev-user-123, got %q", userInfo.Subject)
	}
}

func TestValidateToken_EmptyToken(t *testing.T) {
	validator := NewIAPValidator("test-audience", false)

	ctx := context.Background()
	_, err := validator.ValidateToken(ctx, "")

	if err == nil {
		t.Error("expected error for empty token")
	}
	if err.Error() != "token is empty" {
		t.Errorf("expected 'token is empty' error, got %q", err.Error())
	}
}

func TestValidateToken_InvalidFormat(t *testing.T) {
	validator := NewIAPValidator("test-audience", false)
	ctx := context.Background()

	tests := []struct {
		name  string
		token string
	}{
		{
			name:  "no dots",
			token: "invalidtoken",
		},
		{
			name:  "one dot",
			token: "part1.part2",
		},
		{
			name:  "too many dots",
			token: "part1.part2.part3.part4",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := validator.ValidateToken(ctx, tt.token)
			if err == nil {
				t.Error("expected error for invalid token format")
			}
		})
	}
}

func TestValidateToken_InvalidHeader(t *testing.T) {
	validator := NewIAPValidator("test-audience", false)
	ctx := context.Background()

	// Create token with invalid base64 header
	token := "!!!invalid!!!.eyJ0ZXN0IjoiMSJ9.signature"

	_, err := validator.ValidateToken(ctx, token)
	if err == nil {
		t.Error("expected error for invalid header encoding")
	}
}

func TestValidateToken_UnsupportedAlgorithm(t *testing.T) {
	validator := NewIAPValidator("test-audience", false)
	ctx := context.Background()

	// Create header with unsupported algorithm
	header := map[string]string{
		"alg": "HS256",
		"kid": "key-123",
	}
	headerBytes, _ := json.Marshal(header)
	headerEncoded := base64.RawURLEncoding.EncodeToString(headerBytes)

	payload := map[string]interface{}{
		"iss": "https://cloud.google.com/iap",
		"sub": "user-123",
	}
	payloadBytes, _ := json.Marshal(payload)
	payloadEncoded := base64.RawURLEncoding.EncodeToString(payloadBytes)

	token := headerEncoded + "." + payloadEncoded + ".signature"

	_, err := validator.ValidateToken(ctx, token)
	if err == nil {
		t.Error("expected error for unsupported algorithm")
	}
}

func TestValidateToken_InvalidIssuer(t *testing.T) {
	validator := NewIAPValidator("test-audience", false)
	ctx := context.Background()

	// Create token with invalid issuer
	header := map[string]string{
		"alg": "RS256",
		"kid": "key-123",
	}
	headerBytes, _ := json.Marshal(header)
	headerEncoded := base64.RawURLEncoding.EncodeToString(headerBytes)

	payload := map[string]interface{}{
		"iss":   "https://evil.com",
		"aud":   "test-audience",
		"sub":   "user-123",
		"email": "user@example.com",
		"exp":   time.Now().Add(time.Hour).Unix(),
		"iat":   time.Now().Unix(),
	}
	payloadBytes, _ := json.Marshal(payload)
	payloadEncoded := base64.RawURLEncoding.EncodeToString(payloadBytes)

	token := headerEncoded + "." + payloadEncoded + ".signature"

	_, err := validator.ValidateToken(ctx, token)
	if err == nil {
		t.Error("expected error for invalid issuer")
	}
}

func TestValidateToken_InvalidAudience(t *testing.T) {
	validator := NewIAPValidator("expected-audience", false)
	ctx := context.Background()

	header := map[string]string{
		"alg": "RS256",
		"kid": "key-123",
	}
	headerBytes, _ := json.Marshal(header)
	headerEncoded := base64.RawURLEncoding.EncodeToString(headerBytes)

	payload := map[string]interface{}{
		"iss":   "https://cloud.google.com/iap",
		"aud":   "wrong-audience",
		"sub":   "user-123",
		"email": "user@example.com",
		"exp":   time.Now().Add(time.Hour).Unix(),
		"iat":   time.Now().Unix(),
	}
	payloadBytes, _ := json.Marshal(payload)
	payloadEncoded := base64.RawURLEncoding.EncodeToString(payloadBytes)

	token := headerEncoded + "." + payloadEncoded + ".signature"

	_, err := validator.ValidateToken(ctx, token)
	if err == nil {
		t.Error("expected error for invalid audience")
	}
}

func TestValidateToken_ExpiredToken(t *testing.T) {
	validator := NewIAPValidator("test-audience", false)
	ctx := context.Background()

	header := map[string]string{
		"alg": "RS256",
		"kid": "key-123",
	}
	headerBytes, _ := json.Marshal(header)
	headerEncoded := base64.RawURLEncoding.EncodeToString(headerBytes)

	payload := map[string]interface{}{
		"iss":   "https://cloud.google.com/iap",
		"aud":   "test-audience",
		"sub":   "user-123",
		"email": "user@example.com",
		"exp":   time.Now().Add(-time.Hour).Unix(), // Expired
		"iat":   time.Now().Add(-2 * time.Hour).Unix(),
	}
	payloadBytes, _ := json.Marshal(payload)
	payloadEncoded := base64.RawURLEncoding.EncodeToString(payloadBytes)

	token := headerEncoded + "." + payloadEncoded + ".signature"

	_, err := validator.ValidateToken(ctx, token)
	if err == nil {
		t.Error("expected error for expired token")
	}
}

func TestValidateToken_FutureIssuedAt(t *testing.T) {
	validator := NewIAPValidator("test-audience", false)
	ctx := context.Background()

	header := map[string]string{
		"alg": "RS256",
		"kid": "key-123",
	}
	headerBytes, _ := json.Marshal(header)
	headerEncoded := base64.RawURLEncoding.EncodeToString(headerBytes)

	payload := map[string]interface{}{
		"iss":   "https://cloud.google.com/iap",
		"aud":   "test-audience",
		"sub":   "user-123",
		"email": "user@example.com",
		"exp":   time.Now().Add(2 * time.Hour).Unix(),
		"iat":   time.Now().Add(time.Hour).Unix(), // Issued in future (beyond 5 min skew)
	}
	payloadBytes, _ := json.Marshal(payload)
	payloadEncoded := base64.RawURLEncoding.EncodeToString(payloadBytes)

	token := headerEncoded + "." + payloadEncoded + ".signature"

	_, err := validator.ValidateToken(ctx, token)
	if err == nil {
		t.Error("expected error for token issued in future")
	}
}

func TestSetDevUserEmail(t *testing.T) {
	validator := NewIAPValidator("", true)

	// Default email
	if validator.devUserEmail != "dev@localhost" {
		t.Errorf("expected default email dev@localhost, got %q", validator.devUserEmail)
	}

	// Set custom email
	validator.SetDevUserEmail("custom@test.com")
	if validator.devUserEmail != "custom@test.com" {
		t.Errorf("expected custom email custom@test.com, got %q", validator.devUserEmail)
	}
}

func TestJWKToRSAPublicKey(t *testing.T) {
	// Test with valid JWK values (simplified test)
	jwk := JWK{
		Kty: "RSA",
		Alg: "RS256",
		Kid: "test-key",
		N:   "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMstn64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2QvzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbISD08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw",
		E:   "AQAB",
	}

	key, err := jwkToRSAPublicKey(jwk)
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if key == nil {
		t.Error("expected key to be created")
	}
	if key.E != 65537 {
		t.Errorf("expected exponent 65537, got %d", key.E)
	}
}

func TestJWKToRSAPublicKey_InvalidN(t *testing.T) {
	jwk := JWK{
		Kty: "RSA",
		N:   "!!!invalid-base64!!!",
		E:   "AQAB",
	}

	_, err := jwkToRSAPublicKey(jwk)
	if err == nil {
		t.Error("expected error for invalid N value")
	}
}

func TestJWKToRSAPublicKey_InvalidE(t *testing.T) {
	jwk := JWK{
		Kty: "RSA",
		N:   "AQAB",
		E:   "!!!invalid-base64!!!",
	}

	_, err := jwkToRSAPublicKey(jwk)
	if err == nil {
		t.Error("expected error for invalid E value")
	}
}
