package validation

import (
	"mime/multipart"
	"net/textproto"
	"testing"
)

func TestValidateRoadUsage(t *testing.T) {
	validCases := []string{
		"Auto",
		"Cyclist",
		"Pedestrian",
		"Commercial",
		"Public Transit",
	}

	for _, tc := range validCases {
		t.Run("valid_"+tc, func(t *testing.T) {
			if !validRoadUsages[tc] {
				t.Errorf("expected %q to be valid road usage", tc)
			}
		})
	}

	invalidCases := []string{
		"auto",        // lowercase
		"CYCLIST",     // uppercase
		"Bike",        // not in list
		"",            // empty
		"Car",         // not in list
		"Motorcycle",  // not in list
	}

	for _, tc := range invalidCases {
		t.Run("invalid_"+tc, func(t *testing.T) {
			if validRoadUsages[tc] {
				t.Errorf("expected %q to be invalid road usage", tc)
			}
		})
	}
}

func TestValidateEventType(t *testing.T) {
	validCases := []string{
		"Pedestrian Intersection",
		"Red Light",
		"Speeding",
		"On Phone",
		"Reckless",
	}

	for _, tc := range validCases {
		t.Run("valid_"+tc, func(t *testing.T) {
			if !validEventTypes[tc] {
				t.Errorf("expected %q to be valid event type", tc)
			}
		})
	}

	invalidCases := []string{
		"speeding",       // lowercase
		"RED LIGHT",      // uppercase
		"Accident",       // not in list
		"",               // empty
		"Drunk Driving",  // not in list
	}

	for _, tc := range invalidCases {
		t.Run("invalid_"+tc, func(t *testing.T) {
			if validEventTypes[tc] {
				t.Errorf("expected %q to be invalid event type", tc)
			}
		})
	}
}

func TestValidateStateOrProvince(t *testing.T) {
	// Test US states
	usStates := []string{
		"California",
		"New York",
		"Texas",
		"Florida",
		"District of Columbia",
	}

	for _, tc := range usStates {
		t.Run("valid_US_"+tc, func(t *testing.T) {
			if !validUSStates[tc] {
				t.Errorf("expected %q to be valid US state", tc)
			}
		})
	}

	// Test Canadian provinces
	canadianProvinces := []string{
		"Ontario",
		"Quebec",
		"British Columbia",
		"Alberta",
		"Nova Scotia",
	}

	for _, tc := range canadianProvinces {
		t.Run("valid_CA_"+tc, func(t *testing.T) {
			if !validCanadianProvinces[tc] {
				t.Errorf("expected %q to be valid Canadian province", tc)
			}
		})
	}

	invalidCases := []string{
		"california",  // lowercase
		"NEW YORK",    // uppercase
		"London",      // not in list
		"",            // empty
		"Mexico",      // not in list
	}

	for _, tc := range invalidCases {
		t.Run("invalid_"+tc, func(t *testing.T) {
			if validUSStates[tc] || validCanadianProvinces[tc] {
				t.Errorf("expected %q to be invalid state/province", tc)
			}
		})
	}
}

func TestValidateUUID(t *testing.T) {
	validCases := []string{
		"550e8400-e29b-41d4-a716-446655440000",
		"6ba7b810-9dad-11d1-80b4-00c04fd430c8",
		"f47ac10b-58cc-4372-a567-0e02b2c3d479",
	}

	for _, tc := range validCases {
		t.Run("valid", func(t *testing.T) {
			if !ValidateUUID(tc) {
				t.Errorf("expected %q to be valid UUID", tc)
			}
		})
	}

	invalidCases := []string{
		"not-a-uuid",
		"550e8400-e29b-41d4-a716",           // too short
		"550e8400-e29b-41d4-a716-4466554400", // wrong length
		"",                                   // empty
		"gggggggg-gggg-gggg-gggg-gggggggggggg", // invalid characters
	}

	for _, tc := range invalidCases {
		t.Run("invalid", func(t *testing.T) {
			if ValidateUUID(tc) {
				t.Errorf("expected %q to be invalid UUID", tc)
			}
		})
	}
}

func TestSanitizeFileName(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "normal filename",
			input:    "photo.jpg",
			expected: "photo.jpg",
		},
		{
			name:     "filename with spaces",
			input:    "my photo.jpg",
			expected: "my_photo.jpg",
		},
		{
			name:     "path traversal attempt",
			input:    "../../../etc/passwd",
			expected: "______etc_passwd",
		},
		{
			name:     "windows path",
			input:    "C:\\Windows\\System32\\config",
			expected: "C__Windows_System32_config",
		},
		{
			name:     "null byte injection",
			input:    "file.jpg\x00.exe",
			expected: "file.jpg.exe",
		},
		{
			name:     "special characters",
			input:    "file<>:\"|?*.jpg",
			expected: "file_______.jpg",
		},
		{
			name:     "unicode characters",
			input:    "文件.jpg",
			expected: "__.jpg",
		},
		{
			name:     "double dots",
			input:    "file..jpg",
			expected: "file_jpg",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := SanitizeFileName(tt.input)
			if result != tt.expected {
				t.Errorf("SanitizeFileName(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestValidateFile(t *testing.T) {
	tests := []struct {
		name        string
		contentType string
		size        int64
		wantValid   bool
		wantErrMsg  string
	}{
		{
			name:        "valid jpeg image",
			contentType: "image/jpeg",
			size:        1024 * 1024, // 1MB
			wantValid:   true,
		},
		{
			name:        "valid png image",
			contentType: "image/png",
			size:        5 * 1024 * 1024, // 5MB
			wantValid:   true,
		},
		{
			name:        "image too large",
			contentType: "image/jpeg",
			size:        15 * 1024 * 1024, // 15MB
			wantValid:   false,
			wantErrMsg:  "image file exceeds maximum size of 10MB",
		},
		{
			name:        "valid mp4 video",
			contentType: "video/mp4",
			size:        50 * 1024 * 1024, // 50MB
			wantValid:   true,
		},
		{
			name:        "video too large",
			contentType: "video/mp4",
			size:        150 * 1024 * 1024, // 150MB
			wantValid:   false,
			wantErrMsg:  "video file exceeds maximum size of 100MB",
		},
		{
			name:        "invalid file type",
			contentType: "application/pdf",
			size:        1024,
			wantValid:   false,
			wantErrMsg:  "file type not allowed",
		},
		{
			name:        "executable file",
			contentType: "application/x-executable",
			size:        1024,
			wantValid:   false,
			wantErrMsg:  "file type not allowed",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			header := &multipart.FileHeader{
				Filename: "test.file",
				Size:     tt.size,
				Header:   make(textproto.MIMEHeader),
			}
			header.Header.Set("Content-Type", tt.contentType)

			valid, errMsg := ValidateFile(header)
			if valid != tt.wantValid {
				t.Errorf("ValidateFile() valid = %v, want %v", valid, tt.wantValid)
			}
			if errMsg != tt.wantErrMsg {
				t.Errorf("ValidateFile() errMsg = %q, want %q", errMsg, tt.wantErrMsg)
			}
		})
	}
}

func TestGetAllowedRoadUsages(t *testing.T) {
	usages := GetAllowedRoadUsages()
	if len(usages) != 5 {
		t.Errorf("expected 5 road usages, got %d", len(usages))
	}
}

func TestGetAllowedEventTypes(t *testing.T) {
	types := GetAllowedEventTypes()
	if len(types) != 5 {
		t.Errorf("expected 5 event types, got %d", len(types))
	}
}

func TestGetAllowedStatesAndProvinces(t *testing.T) {
	locations := GetAllowedStatesAndProvinces()
	// 50 US states + DC + 13 Canadian provinces/territories = 64
	if len(locations) != 64 {
		t.Errorf("expected 64 states/provinces, got %d", len(locations))
	}
}
