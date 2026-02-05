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
	"net/http"
	"os"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/youtube/v3"
)

func main() {
	clientID := os.Getenv("YOUTUBE_CLIENT_ID")
	clientSecret := os.Getenv("YOUTUBE_CLIENT_SECRET")

	if clientID == "" || clientSecret == "" {
		log.Fatal("Please set YOUTUBE_CLIENT_ID and YOUTUBE_CLIENT_SECRET environment variables")
	}

	fmt.Printf("Client ID: %s\n", clientID[:20]+"...")
	fmt.Printf("Client Secret: %s...\n", clientSecret[:10]+"...")

	// Use localhost redirect URI (must be configured in Google Cloud Console)
	config := &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint:     google.Endpoint,
		Scopes:       []string{youtube.YoutubeUploadScope},
		RedirectURL:  "http://localhost:8085/callback",
	}

	// Channel to receive the authorization code
	codeChan := make(chan string)
	errChan := make(chan error)

	// Start local server to capture the callback
	server := &http.Server{Addr: ":8085"}
	http.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		if code == "" {
			errChan <- fmt.Errorf("no code in callback: %v", r.URL.Query())
			fmt.Fprintf(w, "<html><body><h1>Error</h1><p>No authorization code received.</p></body></html>")
			return
		}
		fmt.Fprintf(w, "<html><body><h1>Success!</h1><p>Authorization code received. You can close this window.</p></body></html>")
		codeChan <- code
	})

	go func() {
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			errChan <- err
		}
	}()

	// Generate auth URL
	authURL := config.AuthCodeURL("state-token", oauth2.AccessTypeOffline, oauth2.ApprovalForce)

	fmt.Println("\n========================================")
	fmt.Println("YouTube OAuth Token Generator")
	fmt.Println("========================================")
	fmt.Println("\n1. Make sure you've added this redirect URI in Google Cloud Console:")
	fmt.Println("   APIs & Services -> Credentials -> Your OAuth Client -> Authorized redirect URIs")
	fmt.Println("   Add: http://localhost:8085/callback")
	fmt.Println("\n2. Open this URL in your browser:\n")
	fmt.Println(authURL)
	fmt.Println("\n3. Sign in and grant access")
	fmt.Println("\nWaiting for authorization...")

	// Wait for the code
	var code string
	select {
	case code = <-codeChan:
		fmt.Println("\nAuthorization code received!")
	case err := <-errChan:
		log.Fatalf("Error: %v", err)
	}

	// Shutdown the server
	server.Shutdown(context.Background())

	// Exchange code for token
	token, err := config.Exchange(context.Background(), code)
	if err != nil {
		log.Fatalf("Unable to exchange code for token: %v", err)
	}

	fmt.Println("\n========================================")
	fmt.Println("SUCCESS!")
	fmt.Println("========================================")
	fmt.Printf("\nRefresh Token:\n%s\n", token.RefreshToken)
	fmt.Println("\n----------------------------------------")
	fmt.Println("To update in Secret Manager, run:")
	fmt.Println("----------------------------------------")
	fmt.Printf("\necho -n \"%s\" | gcloud secrets versions add youtube-refresh-token --data-file=-\n", token.RefreshToken)
	fmt.Println("\nOr if the secret doesn't exist yet:")
	fmt.Printf("\necho -n \"%s\" | gcloud secrets create youtube-refresh-token --data-file=- --replication-policy=\"automatic\"\n", token.RefreshToken)
}
