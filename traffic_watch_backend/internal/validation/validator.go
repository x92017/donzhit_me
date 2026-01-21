package validation

import (
	"mime/multipart"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin/binding"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
)

// Valid road usage types
var validRoadUsages = map[string]bool{
	"Auto":           true,
	"Cyclist":        true,
	"Pedestrian":     true,
	"Commercial":     true,
	"Public Transit": true,
}

// Valid event types
var validEventTypes = map[string]bool{
	"Pedestrian Intersection": true,
	"Red Light":               true,
	"Speeding":                true,
	"On Phone":                true,
	"Reckless":                true,
}

// Valid US states and DC
var validUSStates = map[string]bool{
	"Alabama": true, "Alaska": true, "Arizona": true, "Arkansas": true,
	"California": true, "Colorado": true, "Connecticut": true, "Delaware": true,
	"Florida": true, "Georgia": true, "Hawaii": true, "Idaho": true,
	"Illinois": true, "Indiana": true, "Iowa": true, "Kansas": true,
	"Kentucky": true, "Louisiana": true, "Maine": true, "Maryland": true,
	"Massachusetts": true, "Michigan": true, "Minnesota": true, "Mississippi": true,
	"Missouri": true, "Montana": true, "Nebraska": true, "Nevada": true,
	"New Hampshire": true, "New Jersey": true, "New Mexico": true, "New York": true,
	"North Carolina": true, "North Dakota": true, "Ohio": true, "Oklahoma": true,
	"Oregon": true, "Pennsylvania": true, "Rhode Island": true, "South Carolina": true,
	"South Dakota": true, "Tennessee": true, "Texas": true, "Utah": true,
	"Vermont": true, "Virginia": true, "Washington": true, "West Virginia": true,
	"Wisconsin": true, "Wyoming": true, "District of Columbia": true,
}

// Valid Canadian provinces and territories
var validCanadianProvinces = map[string]bool{
	"Alberta": true, "British Columbia": true, "Manitoba": true,
	"New Brunswick": true, "Newfoundland and Labrador": true,
	"Northwest Territories": true, "Nova Scotia": true, "Nunavut": true,
	"Ontario": true, "Prince Edward Island": true, "Quebec": true,
	"Saskatchewan": true, "Yukon": true,
}

// File size limits
const (
	MaxImageSize = 10 * 1024 * 1024  // 10MB
	MaxVideoSize = 100 * 1024 * 1024 // 100MB
)

// Allowed MIME types
var allowedImageTypes = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
	"image/gif":  true,
	"image/webp": true,
	"image/heic": true,
	"image/heif": true,
}

var allowedVideoTypes = map[string]bool{
	"video/mp4":       true,
	"video/quicktime": true,
	"video/x-msvideo": true,
	"video/webm":      true,
	"video/mpeg":      true,
}

// RegisterCustomValidators registers all custom validators with Gin
func RegisterCustomValidators() error {
	if v, ok := binding.Validator.Engine().(*validator.Validate); ok {
		if err := v.RegisterValidation("roadusage", validateRoadUsage); err != nil {
			return err
		}
		if err := v.RegisterValidation("eventtype", validateEventType); err != nil {
			return err
		}
		if err := v.RegisterValidation("stateorprovince", validateStateOrProvince); err != nil {
			return err
		}
		if err := v.RegisterValidation("uuid", validateUUID); err != nil {
			return err
		}
	}
	return nil
}

// validateRoadUsage validates road usage types
func validateRoadUsage(fl validator.FieldLevel) bool {
	return validRoadUsages[fl.Field().String()]
}

// validateEventType validates event types
func validateEventType(fl validator.FieldLevel) bool {
	return validEventTypes[fl.Field().String()]
}

// validateStateOrProvince validates US states, DC, and Canadian provinces/territories
func validateStateOrProvince(fl validator.FieldLevel) bool {
	value := fl.Field().String()
	return validUSStates[value] || validCanadianProvinces[value]
}

// validateUUID validates UUID format
func validateUUID(fl validator.FieldLevel) bool {
	_, err := uuid.Parse(fl.Field().String())
	return err == nil
}

// ValidateUUID validates a UUID string
func ValidateUUID(id string) bool {
	_, err := uuid.Parse(id)
	return err == nil
}

// ValidateFile validates an uploaded file
func ValidateFile(header *multipart.FileHeader) (bool, string) {
	contentType := header.Header.Get("Content-Type")

	// Check if it's an allowed image type
	if allowedImageTypes[contentType] {
		if header.Size > MaxImageSize {
			return false, "image file exceeds maximum size of 10MB"
		}
		return true, ""
	}

	// Check if it's an allowed video type
	if allowedVideoTypes[contentType] {
		if header.Size > MaxVideoSize {
			return false, "video file exceeds maximum size of 100MB"
		}
		return true, ""
	}

	return false, "file type not allowed"
}

// SanitizeFileName sanitizes a file name to prevent path traversal
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

// GetAllowedRoadUsages returns all valid road usage types
func GetAllowedRoadUsages() []string {
	result := make([]string, 0, len(validRoadUsages))
	for k := range validRoadUsages {
		result = append(result, k)
	}
	return result
}

// GetAllowedEventTypes returns all valid event types
func GetAllowedEventTypes() []string {
	result := make([]string, 0, len(validEventTypes))
	for k := range validEventTypes {
		result = append(result, k)
	}
	return result
}

// GetAllowedStatesAndProvinces returns all valid states and provinces
func GetAllowedStatesAndProvinces() []string {
	result := make([]string, 0, len(validUSStates)+len(validCanadianProvinces))
	for k := range validUSStates {
		result = append(result, k)
	}
	for k := range validCanadianProvinces {
		result = append(result, k)
	}
	return result
}
