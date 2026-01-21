package middleware

import (
	"testing"
)

func TestSanitizeString(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "plain text",
			input:    "Hello World",
			expected: "Hello World",
		},
		{
			name:     "HTML tags",
			input:    "<b>bold</b>",
			expected: "&lt;b&gt;bold&lt;/b&gt;",
		},
		{
			name:     "script tag",
			input:    "<script>alert('xss')</script>",
			expected: "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;",
		},
		{
			name:     "javascript protocol",
			input:    "javascript:alert(1)",
			expected: "alert(1)",
		},
		{
			name:     "onclick handler",
			input:    "onclick=alert(1)",
			expected: "alert(1)",
		},
		{
			name:     "quotes",
			input:    `"double" and 'single'`,
			expected: `&#34;double&#34; and &#39;single&#39;`,
		},
		{
			name:     "ampersand",
			input:    "Tom & Jerry",
			expected: "Tom &amp; Jerry",
		},
		{
			name:     "null byte",
			input:    "file\x00name",
			expected: "filename",
		},
		{
			name:     "mixed content",
			input:    "<div onclick=alert(1)>Hello</div>",
			expected: "&lt;div alert(1)&gt;Hello&lt;/div&gt;",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := SanitizeString(tt.input)
			if result != tt.expected {
				t.Errorf("SanitizeString(%q) = %q, want %q", tt.input, result, tt.expected)
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
			input:    "document.pdf",
			expected: "document.pdf",
		},
		{
			name:     "path traversal",
			input:    "../../../etc/passwd",
			expected: "______etc_passwd",
		},
		{
			name:     "backslash path",
			input:    "..\\..\\windows\\system32",
			expected: "____windows_system32",
		},
		{
			name:     "null byte",
			input:    "image.jpg\x00.exe",
			expected: "image.jpg.exe",
		},
		{
			name:     "special characters",
			input:    "file@#$%^&().txt",
			expected: "file________.txt",
		},
		{
			name:     "spaces",
			input:    "my file name.txt",
			expected: "my_file_name.txt",
		},
		{
			name:     "long filename",
			input:    string(make([]byte, 300)),
			expected: string(make([]byte, 255)),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := SanitizeFileName(tt.input)

			// For long filename test, just check length
			if tt.name == "long filename" {
				if len(result) > 255 {
					t.Errorf("SanitizeFileName() length = %d, want <= 255", len(result))
				}
				return
			}

			if result != tt.expected {
				t.Errorf("SanitizeFileName(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestSanitizeURL(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "valid https URL",
			input:    "https://example.com/path",
			expected: "https://example.com/path",
		},
		{
			name:     "valid http URL",
			input:    "http://example.com/path",
			expected: "http://example.com/path",
		},
		{
			name:     "javascript protocol",
			input:    "javascript:alert(1)",
			expected: "",
		},
		{
			name:     "data protocol",
			input:    "data:text/html,<script>alert(1)</script>",
			expected: "",
		},
		{
			name:     "javascript in URL",
			input:    "https://example.com/javascript:alert(1)",
			expected: "",
		},
		{
			name:     "no protocol",
			input:    "example.com/path",
			expected: "",
		},
		{
			name:     "ftp protocol",
			input:    "ftp://example.com/file",
			expected: "",
		},
		{
			name:     "file protocol",
			input:    "file:///etc/passwd",
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := SanitizeURL(tt.input)
			if result != tt.expected {
				t.Errorf("SanitizeURL(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestSanitizeValue(t *testing.T) {
	tests := []struct {
		name     string
		input    interface{}
		expected interface{}
	}{
		{
			name:     "string with HTML",
			input:    "<script>alert(1)</script>",
			expected: "&lt;script&gt;alert(1)&lt;/script&gt;",
		},
		{
			name:     "number",
			input:    42,
			expected: 42,
		},
		{
			name:     "boolean",
			input:    true,
			expected: true,
		},
		{
			name:     "nil",
			input:    nil,
			expected: nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := sanitizeValue(tt.input)
			if result != tt.expected {
				t.Errorf("sanitizeValue(%v) = %v, want %v", tt.input, result, tt.expected)
			}
		})
	}
}

func TestSanitizeValueMap(t *testing.T) {
	input := map[string]interface{}{
		"name":        "<script>alert(1)</script>",
		"count":       42,
		"active":      true,
		"description": "Normal text",
	}

	result := sanitizeValue(input).(map[string]interface{})

	if result["name"] != "&lt;script&gt;alert(1)&lt;/script&gt;" {
		t.Errorf("expected sanitized name, got %v", result["name"])
	}
	if result["count"] != 42 {
		t.Errorf("expected count to be 42, got %v", result["count"])
	}
	if result["active"] != true {
		t.Errorf("expected active to be true, got %v", result["active"])
	}
	if result["description"] != "Normal text" {
		t.Errorf("expected description to be unchanged, got %v", result["description"])
	}
}

func TestSanitizeValueSlice(t *testing.T) {
	input := []interface{}{
		"<b>bold</b>",
		"normal",
		42,
	}

	result := sanitizeValue(input).([]interface{})

	if result[0] != "&lt;b&gt;bold&lt;/b&gt;" {
		t.Errorf("expected sanitized first element, got %v", result[0])
	}
	if result[1] != "normal" {
		t.Errorf("expected unchanged second element, got %v", result[1])
	}
	if result[2] != 42 {
		t.Errorf("expected number to be unchanged, got %v", result[2])
	}
}

func TestMatchOrigin(t *testing.T) {
	tests := []struct {
		name    string
		origin  string
		pattern string
		want    bool
	}{
		{
			name:    "exact match",
			origin:  "https://example.com",
			pattern: "https://example.com",
			want:    true,
		},
		{
			name:    "wildcard all",
			origin:  "https://anything.com",
			pattern: "*",
			want:    true,
		},
		{
			name:    "subdomain wildcard",
			origin:  "https://app.example.com",
			pattern: "https://*.example.com",
			want:    true,
		},
		{
			name:    "port wildcard",
			origin:  "http://localhost:3000",
			pattern: "http://localhost:*",
			want:    true,
		},
		{
			name:    "no match",
			origin:  "https://evil.com",
			pattern: "https://example.com",
			want:    false,
		},
		{
			name:    "subdomain no match",
			origin:  "https://evil.com",
			pattern: "https://*.example.com",
			want:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := matchOrigin(tt.origin, tt.pattern)
			if got != tt.want {
				t.Errorf("matchOrigin(%q, %q) = %v, want %v", tt.origin, tt.pattern, got, tt.want)
			}
		})
	}
}
