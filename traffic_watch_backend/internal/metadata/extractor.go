package metadata

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/abema/go-mp4"
	"github.com/rwcarlsen/goexif/exif"
	"github.com/rwcarlsen/goexif/tiff"
)

// ExtractImageMetadata extracts EXIF metadata from an image
func ExtractImageMetadata(r io.Reader) (map[string]interface{}, error) {
	x, err := exif.Decode(r)
	if err != nil {
		// No EXIF data or unsupported format
		return nil, nil
	}

	metadata := make(map[string]interface{})

	// Walk through all EXIF fields
	walker := &exifWalker{data: metadata}
	if err := x.Walk(walker); err != nil {
		return nil, err
	}

	// Extract GPS coordinates if available
	lat, lon, err := x.LatLong()
	if err == nil {
		metadata["gps_latitude"] = lat
		metadata["gps_longitude"] = lon
	}

	// Extract common fields with friendly names
	if dt, err := x.DateTime(); err == nil {
		metadata["date_time_original"] = dt.Format("2006-01-02T15:04:05")
	}

	return metadata, nil
}

// exifWalker implements exif.Walker to extract all EXIF fields
type exifWalker struct {
	data map[string]interface{}
}

func (w *exifWalker) Walk(name exif.FieldName, tag *tiff.Tag) error {
	// Convert field name to snake_case for consistency
	key := toSnakeCase(string(name))

	// Get the value based on tag format
	switch tag.Format() {
	case tiff.StringVal:
		val, err := tag.StringVal()
		if err == nil && val != "" {
			w.data[key] = strings.TrimSpace(val)
		}
	case tiff.IntVal:
		if tag.Count == 1 {
			val, err := tag.Int(0)
			if err == nil {
				w.data[key] = val
			}
		} else {
			vals := make([]int, tag.Count)
			for i := 0; i < int(tag.Count); i++ {
				val, err := tag.Int(i)
				if err == nil {
					vals[i] = val
				}
			}
			w.data[key] = vals
		}
	case tiff.FloatVal:
		if tag.Count == 1 {
			val, err := tag.Float(0)
			if err == nil {
				w.data[key] = val
			}
		} else {
			vals := make([]float64, tag.Count)
			for i := 0; i < int(tag.Count); i++ {
				val, err := tag.Float(i)
				if err == nil {
					vals[i] = val
				}
			}
			w.data[key] = vals
		}
	case tiff.RatVal:
		if tag.Count == 1 {
			rat, err := tag.Rat(0)
			if err == nil {
				f, _ := rat.Float64()
				w.data[key] = f
			}
		} else {
			vals := make([]float64, tag.Count)
			for i := 0; i < int(tag.Count); i++ {
				rat, err := tag.Rat(i)
				if err == nil {
					f, _ := rat.Float64()
					vals[i] = f
				}
			}
			w.data[key] = vals
		}
	default:
		// For other types, use string representation
		w.data[key] = tag.String()
	}

	return nil
}

// ExtractVideoMetadata extracts metadata from MP4/MOV video files
func ExtractVideoMetadata(r io.ReadSeeker, contentType string) (map[string]interface{}, error) {
	metadata := make(map[string]interface{})
	metadata["media_type"] = "video"
	metadata["content_type"] = contentType

	// Try to parse as MP4
	if contentType == "video/mp4" || contentType == "video/quicktime" || contentType == "video/mov" {
		mp4Meta, err := extractMP4Metadata(r)
		if err == nil && mp4Meta != nil {
			for k, v := range mp4Meta {
				metadata[k] = v
			}
		}
	}

	return metadata, nil
}

// extractMP4Metadata parses MP4 file structure to extract metadata
func extractMP4Metadata(r io.ReadSeeker) (map[string]interface{}, error) {
	metadata := make(map[string]interface{})

	// Use go-mp4 to read boxes
	boxes, err := mp4.ExtractBoxWithPayload(r, nil, mp4.BoxPath{mp4.BoxTypeMoov()})
	if err != nil {
		return nil, err
	}

	for _, box := range boxes {
		if box.Info.Type == mp4.BoxTypeMoov() {
			// Found moov box, now look for metadata inside
			r.Seek(int64(box.Info.Offset), io.SeekStart)
			extractMoovMetadata(r, int64(box.Info.Size), metadata)
		}
	}

	// Try to extract mvhd (movie header) for creation time and duration
	r.Seek(0, io.SeekStart)
	mvhdBoxes, err := mp4.ExtractBoxWithPayload(r, nil, mp4.BoxPath{mp4.BoxTypeMoov(), mp4.BoxTypeMvhd()})
	if err == nil && len(mvhdBoxes) > 0 {
		if mvhd, ok := mvhdBoxes[0].Payload.(*mp4.Mvhd); ok {
			// Creation time is seconds since 1904-01-01
			if mvhd.CreationTimeV0 > 0 {
				creationTime := mp4TimeToUnix(uint64(mvhd.CreationTimeV0))
				metadata["creation_time"] = creationTime.Format("2006-01-02T15:04:05Z")
			} else if mvhd.CreationTimeV1 > 0 {
				creationTime := mp4TimeToUnix(mvhd.CreationTimeV1)
				metadata["creation_time"] = creationTime.Format("2006-01-02T15:04:05Z")
			}

			// Duration
			var timescale uint32
			if mvhd.Timescale > 0 {
				timescale = mvhd.Timescale
			} else {
				timescale = 1000
			}

			var duration uint64
			if mvhd.DurationV0 > 0 {
				duration = uint64(mvhd.DurationV0)
			} else {
				duration = mvhd.DurationV1
			}

			if timescale > 0 && duration > 0 {
				durationSecs := float64(duration) / float64(timescale)
				metadata["duration_seconds"] = math.Round(durationSecs*100) / 100
			}
		}
	}

	// Try to get video dimensions from trak/tkhd
	r.Seek(0, io.SeekStart)
	tkhdBoxes, err := mp4.ExtractBoxWithPayload(r, nil, mp4.BoxPath{mp4.BoxTypeMoov(), mp4.BoxTypeTrak(), mp4.BoxTypeTkhd()})
	if err == nil && len(tkhdBoxes) > 0 {
		for _, tkhdBox := range tkhdBoxes {
			if tkhd, ok := tkhdBox.Payload.(*mp4.Tkhd); ok {
				// Width and height are fixed-point 16.16 values
				width := tkhd.Width >> 16
				height := tkhd.Height >> 16
				if width > 0 && height > 0 {
					metadata["width"] = width
					metadata["height"] = height
					break
				}
			}
		}
	}

	// Try to extract GPS from udta box (Apple format)
	r.Seek(0, io.SeekStart)
	extractGPSFromUdta(r, metadata)

	return metadata, nil
}

// extractMoovMetadata extracts metadata from within the moov box
func extractMoovMetadata(r io.ReadSeeker, moovSize int64, metadata map[string]interface{}) {
	// Look for udta (user data) box which contains metadata
	startPos, _ := r.Seek(0, io.SeekCurrent)
	endPos := startPos + moovSize

	buf := make([]byte, 8)
	for {
		pos, _ := r.Seek(0, io.SeekCurrent)
		if pos >= endPos {
			break
		}

		n, err := r.Read(buf)
		if err != nil || n < 8 {
			break
		}

		boxSize := binary.BigEndian.Uint32(buf[0:4])
		boxType := string(buf[4:8])

		if boxSize == 0 {
			break
		}

		if boxType == "udta" {
			// Found user data box, look for GPS
			extractUdtaContent(r, int64(boxSize)-8, metadata)
		}

		// Move to next box
		if boxSize > 8 {
			r.Seek(pos+int64(boxSize), io.SeekStart)
		} else {
			break
		}
	}
}

// extractUdtaContent extracts content from udta box
func extractUdtaContent(r io.ReadSeeker, size int64, metadata map[string]interface{}) {
	startPos, _ := r.Seek(0, io.SeekCurrent)
	endPos := startPos + size

	buf := make([]byte, 8)
	for {
		pos, _ := r.Seek(0, io.SeekCurrent)
		if pos >= endPos {
			break
		}

		n, err := r.Read(buf)
		if err != nil || n < 8 {
			break
		}

		boxSize := binary.BigEndian.Uint32(buf[0:4])
		boxType := string(buf[4:8])

		if boxSize == 0 || boxSize < 8 {
			break
		}

		// Look for GPS coordinate box (©xyz or similar)
		if boxType == "©xyz" || boxType == "\xa9xyz" {
			// GPS data in Apple format: "+34.0522-118.2437/"
			dataSize := int(boxSize) - 8
			if dataSize > 0 && dataSize < 1000 {
				gpsData := make([]byte, dataSize)
				r.Read(gpsData)
				parseAppleGPS(string(gpsData), metadata)
				continue
			}
		}

		// Move to next box
		r.Seek(pos+int64(boxSize), io.SeekStart)
	}
}

// extractGPSFromUdta tries to find GPS data in the udta box using raw scanning
func extractGPSFromUdta(r io.ReadSeeker, metadata map[string]interface{}) {
	// Read entire file to search for GPS pattern
	r.Seek(0, io.SeekStart)
	data, err := io.ReadAll(r)
	if err != nil {
		return
	}

	// Look for Apple GPS format: "+/-DD.DDDD+/-DDD.DDDD/" or similar
	// Pattern: coordinates like "+34.0522-118.2437/"
	gpsPattern := regexp.MustCompile(`([+-]\d{1,3}\.\d+)([+-]\d{1,3}\.\d+)/?`)

	// Search for ©xyz or @xyz marker followed by GPS data
	xyzPatterns := [][]byte{
		[]byte("\xa9xyz"),
		[]byte("©xyz"),
		[]byte("@xyz"),
	}

	for _, pattern := range xyzPatterns {
		idx := bytes.Index(data, pattern)
		if idx >= 0 && idx+50 < len(data) {
			// Found marker, look for GPS data after it
			searchArea := string(data[idx : idx+100])
			matches := gpsPattern.FindStringSubmatch(searchArea)
			if len(matches) >= 3 {
				lat, err1 := strconv.ParseFloat(matches[1], 64)
				lon, err2 := strconv.ParseFloat(matches[2], 64)
				if err1 == nil && err2 == nil {
					metadata["gps_latitude"] = lat
					metadata["gps_longitude"] = lon
					return
				}
			}
		}
	}
}

// parseAppleGPS parses GPS coordinates in Apple format
func parseAppleGPS(data string, metadata map[string]interface{}) {
	// Format: "+34.0522-118.2437/" or "ISO 6709 format"
	// Remove any leading bytes (size/type info that might be included)
	cleaned := strings.TrimSpace(data)

	// Try to find coordinates pattern
	pattern := regexp.MustCompile(`([+-]\d{1,3}\.\d+)([+-]\d{1,3}\.\d+)`)
	matches := pattern.FindStringSubmatch(cleaned)

	if len(matches) >= 3 {
		lat, err1 := strconv.ParseFloat(matches[1], 64)
		lon, err2 := strconv.ParseFloat(matches[2], 64)
		if err1 == nil && err2 == nil {
			metadata["gps_latitude"] = lat
			metadata["gps_longitude"] = lon
		}
	}
}

// mp4TimeToUnix converts MP4 timestamp (seconds since 1904-01-01) to time.Time
func mp4TimeToUnix(mp4Time uint64) time.Time {
	// MP4 epoch is January 1, 1904
	// Unix epoch is January 1, 1970
	// Difference is 2082844800 seconds
	const mp4EpochOffset = 2082844800

	if mp4Time < mp4EpochOffset {
		return time.Time{}
	}

	unixTime := int64(mp4Time) - mp4EpochOffset
	return time.Unix(unixTime, 0).UTC()
}

// IsImageContentType checks if the content type is an image
func IsImageContentType(contentType string) bool {
	return strings.HasPrefix(contentType, "image/")
}

// IsVideoContentType checks if the content type is a video
func IsVideoContentType(contentType string) bool {
	return strings.HasPrefix(contentType, "video/")
}

// toSnakeCase converts a string to snake_case
func toSnakeCase(s string) string {
	var result strings.Builder
	for i, r := range s {
		if i > 0 && r >= 'A' && r <= 'Z' {
			result.WriteRune('_')
		}
		if r >= 'A' && r <= 'Z' {
			result.WriteRune(r + 32) // lowercase
		} else {
			result.WriteRune(r)
		}
	}
	return result.String()
}

// ExtractMetadata extracts metadata based on content type
func ExtractMetadata(r io.ReadSeeker, contentType string) (map[string]interface{}, error) {
	if IsImageContentType(contentType) {
		return ExtractImageMetadata(r)
	}
	if IsVideoContentType(contentType) {
		return ExtractVideoMetadata(r, contentType)
	}
	return nil, fmt.Errorf("unsupported content type: %s", contentType)
}
