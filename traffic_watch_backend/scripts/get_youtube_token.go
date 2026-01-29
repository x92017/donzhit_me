// This script helps you get a YouTube OAuth refresh token
// Run: go run scripts/get_youtube_token.go
//
// You'll need to set these environment variables:
//   YOUTUBE_CLIENT_ID=your-client-id
//   YOUTUBE_CLIENT_SECRET=your-client-secret

package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/youtube/v3"
)

func main() {
	clientID := os.Getenv("YOUTUBE_CLIENT_ID")
	print("cliendID:", clientID)
	clientSecret := os.Getenv("YOUTUBE_CLIENT_SECRET")
	print("clientSecret:", clientSecret)

	if clientID == "" || clientSecret == "" {
		log.Fatal("Please set YOUTUBE_CLIENT_ID and YOUTUBE_CLIENT_SECRET environment variables")
	}

	config := &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint:     google.Endpoint,
		Scopes:       []string{youtube.YoutubeUploadScope},
		RedirectURL:  "urn:ietf:wg:oauth:2.0:oob",
	}

	// Generate auth URL
	authURL := config.AuthCodeURL("state-token", oauth2.AccessTypeOffline)
	fmt.Printf("\n1. Open this URL in your browser:\n\n%s\n\n", authURL)
	fmt.Println("2. Sign in with jeffarbaugh@gmail.com")
	fmt.Println("3. Grant access to upload videos")
	fmt.Println("4. Copy the authorization code and paste it below")
	fmt.Print("\nAuthorization code: ")

	var code string
	if _, err := fmt.Scan(&code); err != nil {
		log.Fatalf("Unable to read authorization code: %v", err)
	}

	// Exchange code for token
	token, err := config.Exchange(context.Background(), code)
	if err != nil {
		log.Fatalf("Unable to exchange code for token: %v", err)
	}

	fmt.Println("\n=== SUCCESS ===")
	fmt.Printf("\nRefresh Token: %s\n", token.RefreshToken)
	fmt.Println("\nStore this refresh token in Secret Manager:")
	fmt.Printf("\necho -n \"%s\" | gcloud secrets create youtube-refresh-token --data-file=- --replication-policy=\"automatic\"\n", token.RefreshToken)
}
