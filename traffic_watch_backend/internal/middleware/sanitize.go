package middleware

import (
	"bytes"
	"encoding/json"
	"html"
	"io"
	"net/http"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
)

// Common XSS patterns to strip
var xssPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)<script[^>]*>.*?</script>`),
	regexp.MustCompile(`(?i)<iframe[^>]*>.*?</iframe>`),
	regexp.MustCompile(`(?i)javascript:`),
	regexp.MustCompile(`(?i)on\w+\s*=`),
	regexp.MustCompile(`(?i)data:\s*text/html`),
}

// SanitizeOutput returns a middleware that sanitizes JSON responses
func SanitizeOutput() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Create a response writer wrapper
		writer := &sanitizeResponseWriter{
			ResponseWriter: c.Writer,
			body:           &bytes.Buffer{},
		}
		c.Writer = writer

		c.Next()

		// Only sanitize JSON responses
		contentType := c.Writer.Header().Get("Content-Type")
		if !strings.Contains(contentType, "application/json") {
			// Write original body for non-JSON responses
			writer.ResponseWriter.Write(writer.body.Bytes())
			return
		}

		// Parse and sanitize JSON
		var data interface{}
		if err := json.Unmarshal(writer.body.Bytes(), &data); err != nil {
			// If can't parse, write original
			writer.ResponseWriter.Write(writer.body.Bytes())
			return
		}

		sanitized := sanitizeValue(data)
		output, err := json.Marshal(sanitized)
		if err != nil {
			writer.ResponseWriter.Write(writer.body.Bytes())
			return
		}

		writer.ResponseWriter.Write(output)
	}
}

// sanitizeResponseWriter wraps gin.ResponseWriter to capture the response body
type sanitizeResponseWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (w *sanitizeResponseWriter) Write(data []byte) (int, error) {
	return w.body.Write(data)
}

// sanitizeValue recursively sanitizes a value
func sanitizeValue(v interface{}) interface{} {
	switch val := v.(type) {
	case string:
		return SanitizeString(val)
	case map[string]interface{}:
		result := make(map[string]interface{})
		for k, v := range val {
			result[SanitizeString(k)] = sanitizeValue(v)
		}
		return result
	case []interface{}:
		result := make([]interface{}, len(val))
		for i, v := range val {
			result[i] = sanitizeValue(v)
		}
		return result
	default:
		return val
	}
}

// SanitizeString sanitizes a string to prevent XSS
func SanitizeString(s string) string {
	// HTML escape
	s = html.EscapeString(s)

	// Strip XSS patterns (after escape, mainly for stored content)
	for _, pattern := range xssPatterns {
		s = pattern.ReplaceAllString(s, "")
	}

	// Remove null bytes
	s = strings.ReplaceAll(s, "\x00", "")

	return s
}

// SanitizeFileName sanitizes a file name
func SanitizeFileName(fileName string) string {
	// Remove path separators
	fileName = strings.ReplaceAll(fileName, "/", "_")
	fileName = strings.ReplaceAll(fileName, "\\", "_")
	fileName = strings.ReplaceAll(fileName, "..", "_")

	// Remove null bytes
	fileName = strings.ReplaceAll(fileName, "\x00", "")

	// Keep only safe characters
	reg := regexp.MustCompile(`[^a-zA-Z0-9._-]`)
	fileName = reg.ReplaceAllString(fileName, "_")

	// Limit length
	if len(fileName) > 255 {
		fileName = fileName[:255]
	}

	return fileName
}

// SanitizeURL validates and sanitizes a URL
func SanitizeURL(urlStr string) string {
	// Only allow http and https schemes
	if !strings.HasPrefix(urlStr, "http://") && !strings.HasPrefix(urlStr, "https://") {
		return ""
	}

	// Check for javascript: or data: schemes hidden in the URL
	lower := strings.ToLower(urlStr)
	if strings.Contains(lower, "javascript:") || strings.Contains(lower, "data:") {
		return ""
	}

	return urlStr
}

// RequestSizeLimit returns a middleware that limits request body size
func RequestSizeLimit(maxBytes int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)

		// Try to read a single byte to trigger the limit check
		bodyBytes, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusRequestEntityTooLarge, gin.H{
				"error":   "request_too_large",
				"message": "request body exceeds maximum allowed size",
			})
			return
		}

		// Restore the body for downstream handlers
		c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
		c.Next()
	}
}
