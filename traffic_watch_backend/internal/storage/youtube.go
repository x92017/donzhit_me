package storage

import (
	"context"
	"fmt"
	"io"
	"log"
	"strings"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/option"
	"google.golang.org/api/youtube/v3"
)

// YouTubeClient handles video uploads to YouTube
type YouTubeClient struct {
	service *youtube.Service
}

// YouTubeUploadResult contains the result of a YouTube upload
type YouTubeUploadResult struct {
	VideoID string
	URL     string
}

// NewYouTubeClient creates a new YouTube client using OAuth2 refresh token
func NewYouTubeClient(ctx context.Context, clientID, clientSecret, refreshToken string) (*YouTubeClient, error) {
	config := &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint:     google.Endpoint,
		Scopes:       []string{youtube.YoutubeUploadScope},
	}

	token := &oauth2.Token{
		RefreshToken: refreshToken,
	}

	tokenSource := config.TokenSource(ctx, token)
	service, err := youtube.NewService(ctx, option.WithTokenSource(tokenSource))
	if err != nil {
		return nil, fmt.Errorf("failed to create YouTube service: %w", err)
	}

	return &YouTubeClient{
		service: service,
	}, nil
}

// UploadVideo uploads a video to YouTube and returns the video ID and URL
func (y *YouTubeClient) UploadVideo(ctx context.Context, title, description string, reader io.Reader, contentType string) (*YouTubeUploadResult, error) {
	upload := &youtube.Video{
		Snippet: &youtube.VideoSnippet{
			Title:       title,
			Description: description,
			CategoryId:  "22", // People & Blogs category
		},
		Status: &youtube.VideoStatus{
			PrivacyStatus: "unlisted", // unlisted so only people with the link can view
		},
	}

	call := y.service.Videos.Insert([]string{"snippet", "status"}, upload)
	call.Media(reader)

	log.Printf("Uploading video to YouTube: %s", title)
	response, err := call.Context(ctx).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to upload video to YouTube: %w", err)
	}

	result := &YouTubeUploadResult{
		VideoID: response.Id,
		URL:     fmt.Sprintf("https://www.youtube.com/watch?v=%s", response.Id),
	}

	log.Printf("Video uploaded successfully: %s", result.URL)
	return result, nil
}

// IsVideoContentType checks if the content type is a video
func IsVideoContentType(contentType string) bool {
	contentType = strings.ToLower(contentType)
	videoTypes := []string{
		"video/mp4",
		"video/quicktime",
		"video/x-msvideo",
		"video/x-ms-wmv",
		"video/mpeg",
		"video/webm",
		"video/3gpp",
		"video/3gpp2",
		"video/x-flv",
		"video/x-matroska",
	}
	for _, vt := range videoTypes {
		if contentType == vt {
			return true
		}
	}
	return false
}

// IsImageContentType checks if the content type is an image
func IsImageContentType(contentType string) bool {
	contentType = strings.ToLower(contentType)
	imageTypes := []string{
		"image/jpeg",
		"image/png",
		"image/gif",
		"image/webp",
		"image/heic",
		"image/heif",
	}
	for _, it := range imageTypes {
		if contentType == it {
			return true
		}
	}
	return false
}
