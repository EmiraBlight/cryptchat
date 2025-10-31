package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"os/exec"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/lib/pq"
	"google.golang.org/api/option"
)

var (
	db          *pgxpool.Pool
	authClient  *auth.Client
	charset     = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	chatroomCap = 10
)

// generateRandomID generates a random string for chat IDs
func generateRandomID(length int) string {
	b := make([]byte, length)
	for i := range b {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		b[i] = charset[n.Int64()]
	}
	return string(b)
}

func verifyFirebaseToken(c *gin.Context) (*auth.Token, error) {
	authHeader := c.GetHeader("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return nil, fmt.Errorf("missing token")
	}
	idToken := strings.TrimPrefix(authHeader, "Bearer ")

	token, err := authClient.VerifyIDToken(context.Background(), idToken)
	if err != nil {
		return nil, fmt.Errorf("invalid token: %v", err)
	}
	return token, nil
}

func getUIDFromToken(c *gin.Context) (string, error) {
	authHeader := c.GetHeader("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return "", fmt.Errorf("missing token")
	}
	idToken := strings.TrimPrefix(authHeader, "Bearer ")
	token, err := authClient.VerifyIDToken(context.Background(), idToken)
	if err != nil {
		return "", err
	}
	return token.UID, nil
}

func addUser(c *gin.Context) {
	// Verify token and extract UID + Email
	token, err := verifyFirebaseToken(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}
	uid := token.UID
	email := token.Claims["email"]
	emailStr, _ := email.(string) // safely cast to string

	// Parse JSON body
	var data struct {
		Username string `json:"username"`
	}
	if err := c.BindJSON(&data); err != nil || strings.TrimSpace(data.Username) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username required"})
		return
	}

	// Check if user already has a username
	var count int
	err = db.QueryRow(context.Background(),
		"SELECT COUNT(*) FROM users WHERE firebase_uid=$1", uid).Scan(&count)
	if err == nil && count > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User already has a username"})
		return
	}

	// Check if username is already taken
	err = db.QueryRow(context.Background(),
		"SELECT COUNT(*) FROM users WHERE username=$1", data.Username).Scan(&count)
	if err == nil && count > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username already taken"})
		return
	}

	// Insert new user with email
	_, err = db.Exec(context.Background(),
		"INSERT INTO users (firebase_uid, username, email) VALUES ($1, $2, $3)",
		uid, data.Username, emailStr)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":   "success",
		"uid":      uid,
		"username": data.Username,
		"email":    emailStr,
	})
}

func getUsername(c *gin.Context) {
	uid, err := getUIDFromToken(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var username string
	err = db.QueryRow(context.Background(), "SELECT username FROM users WHERE firebase_uid=$1", uid).Scan(&username)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success", "username": username})
}

type keyPair struct {
	PrivateKey string `json:"private_key"`
	PublicKey  string `json:"public_key"`
}

type KeyprocResult struct {
	Ciphertext   string `json:"ciphertext"`
	Nonce        string `json:"nonce"`
	ServerPubKey string `json:"server_pubkey"`
}

// generateKeyPair calls the external Rust keygen program
func generateKeyPair() (*keyPair, error) {
	cmd := exec.Command("./keygen")

	var out bytes.Buffer
	cmd.Stdout = &out

	err := cmd.Run()
	if err != nil {
		return nil, err
	}

	var kp keyPair
	if err := json.Unmarshal(out.Bytes(), &kp); err != nil {
		return nil, err
	}

	return &kp, nil
}

func createChat(c *gin.Context) {
	uid, err := getUIDFromToken(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var data struct {
		Users    []string `json:"users"`
		ChatName string   `json:"chatName"` // new chat name
	}
	if err := c.BindJSON(&data); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Validate chat name length
	if len(data.ChatName) == 0 || len(data.ChatName) > 128 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Chat name must be 1-128 characters"})
		return
	}

	// Build list of UIDs including creator
	uids := []string{uid}
	for _, username := range data.Users {
		var otherUID string
		err := db.QueryRow(context.Background(),
			"SELECT firebase_uid FROM users WHERE username=$1", username).Scan(&otherUID)
		if err == nil && otherUID != "" {
			uids = append(uids, otherUID)
		}
	}

	// Generate unique chatID
	var chatID string
	for {
		chatID = generateRandomID(64)
		var exists int
		err := db.QueryRow(context.Background(),
			"SELECT COUNT(*) FROM chatrooms WHERE chat_id=$1", chatID).Scan(&exists)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if exists == 0 {
			break
		}
	}

	// Fill with random users if needed
	remaining := chatroomCap - len(uids)
	if remaining > 0 {
		rows, err := db.Query(context.Background(), "SELECT firebase_uid FROM users")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		var all []string
		for rows.Next() {
			var id string
			rows.Scan(&id)
			if id != "" {
				all = append(all, id)
			}
		}

		// Shuffle
		for i := len(all) - 1; i > 0; i-- {
			jBig, _ := rand.Int(rand.Reader, big.NewInt(int64(i+1)))
			j := int(jBig.Int64())
			all[i], all[j] = all[j], all[i]
		}

		if len(all) > remaining {
			uids = append(uids, all[:remaining]...)
		} else {
			uids = append(uids, all...)
		}
	}

	// Generate keys for each user
	publicKeys := make([]string, len(uids))
	privateKeys := make([]string, len(uids))
	for i := range uids {
		cmd := exec.Command("./keygen")
		out, err := cmd.Output()
		if err != nil {
			log.Printf("keygen error for %s: %v", uids[i], err)
			continue
		}

		var keys struct {
			PrivateKey string `json:"private_key"`
			PublicKey  string `json:"public_key"`
		}
		if err := json.Unmarshal(out, &keys); err != nil {
			log.Printf("Failed to parse keygen output: %v", err)
			continue
		}
		publicKeys[i] = keys.PublicKey
		privateKeys[i] = keys.PrivateKey
	}

	// Insert chatroom
	_, err = db.Exec(context.Background(),
		"INSERT INTO chatrooms (chat_id, char_users, messages, public_keys) VALUES ($1, $2, $3, $4)",
		chatID, pq.Array(uids), pq.Array([]string{}), pq.Array(publicKeys))
	if err != nil {
		log.Println("DB Insert Error:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error", "details": err.Error()})
		return
	}

	// Get creator's username
	var senderUsername string
	err = db.QueryRow(context.Background(),
		"SELECT username FROM users WHERE firebase_uid=$1", uid).Scan(&senderUsername)
	if err != nil {
		senderUsername = "unknown"
	}

	type KeyGenResult struct {
		Ciphertext   string `json:"ciphertext"`
		Nonce        string `json:"nonce"`
		ServerPubKey string `json:"server_pubkey"`
	}

	// Create invites (creator + invited users)
	for i, userUID := range uids[:len(data.Users)+1] {
		var globalPub string
		err := db.QueryRow(context.Background(),
			"SELECT pub_key FROM users WHERE firebase_uid=$1", userUID).Scan(&globalPub)
		if err != nil || globalPub == "" {
			log.Printf("Skipping invite for %s: missing pub_key", userUID)
			continue
		}

		// Encrypt plaintext: chatID;invitingUser;privateKey;chatName
		message := fmt.Sprintf("%s;%s;%s;%s", chatID, senderUsername, privateKeys[i], data.ChatName)

		cmd := exec.Command("./keygen", globalPub, message)
		out, err := cmd.Output()
		if err != nil {
			log.Printf("keygen failed for %s: %v", userUID, err)
			continue
		}

		var enc KeyGenResult
		if err := json.Unmarshal(out, &enc); err != nil {
			log.Printf("Failed to parse keygen output for %s: %v", userUID, err)
			continue
		}

		// Store invite in DB
		_, err = db.Exec(context.Background(),
			"INSERT INTO invitations (recipient_uid, ciphertext, nonce, server_pubkey) VALUES ($1, $2, $3, $4)",
			userUID, enc.Ciphertext, enc.Nonce, enc.ServerPubKey)
		if err != nil {
			log.Printf("Failed to insert invite for %s: %v", userUID, err)
			continue
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       "chat created and invites sent",
		"chatroom_hint": "chat ID stored internally; invite required for join",
	})
}

func searchUsers(c *gin.Context) {
	uid, err := getUIDFromToken(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	query := c.Query("q")
	if strings.TrimSpace(query) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing search query"})
		return
	}

	rows, err := db.Query(context.Background(), `
		SELECT username FROM users
		WHERE username ILIKE $1 AND firebase_uid != $2
		ORDER BY username ASC LIMIT 10
	`, "%"+query+"%", uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var users []string
	for rows.Next() {
		var uname string
		rows.Scan(&uname)
		users = append(users, uname)
	}

	c.JSON(http.StatusOK, gin.H{"results": users})
}

func storePublicKey(c *gin.Context) {
	uid, err := getUIDFromToken(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	var data struct {
		PublicKey string `json:"public_key"`
	}
	if err := c.BindJSON(&data); err != nil || data.PublicKey == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing public_key"})
		return
	}

	_, err = db.Exec(context.Background(),
		"UPDATE users SET pub_key=$1 WHERE firebase_uid=$2", data.PublicKey, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success"})
}

func getInvites(c *gin.Context) {
	uid, err := getUIDFromToken(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	rows, err := db.Query(context.Background(),
		`SELECT id, ciphertext, nonce, server_pubkey
		 FROM invitations
		 WHERE recipient_uid=$1
		 ORDER BY created_at DESC`, uid)
	if err != nil {
		log.Printf("DB error fetching invites for %s: %v", uid, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	defer rows.Close()

	type Invite struct {
		ID         int    `json:"id"`
		Ciphertext string `json:"ciphertext"`
		Nonce      string `json:"nonce"`
		ServerPub  string `json:"server_pubkey"`
		CreatedAt  string `json:"created_at,omitempty"`
	}

	var invites []Invite
	for rows.Next() {
		var inv Invite
		if err := rows.Scan(&inv.ID, &inv.Ciphertext, &inv.Nonce, &inv.ServerPub); err == nil {
			invites = append(invites, inv)
		}
	}

	if len(invites) == 0 {
		c.JSON(http.StatusOK, gin.H{"invites": []Invite{}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"invites": invites,
	})
}

func main() {
	log.Println("Starting intiliation")
	if err := godotenv.Load(); err != nil {
		log.Println("No .env found, using system vars")
	}

	// Connect DB
	dbURL := fmt.Sprintf("postgres://%s:%s@%s/%s",
		os.Getenv("DB_USER"), os.Getenv("DB_PASS"),
		os.Getenv("DB_HOST"), os.Getenv("DB_NAME"))

	var err error
	db, err = pgxpool.New(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to DB: %v", err)
	}
	defer db.Close()
	log.Println("Connected to database.")

	// Init Firebase
	opt := option.WithCredentialsFile("firebase_admin.json")
	app, err := firebase.NewApp(context.Background(), nil, opt)
	if err != nil {
		log.Fatalf("Firebase init error: %v", err)
	}
	authClient, err = app.Auth(context.Background())
	if err != nil {
		log.Fatalf("Auth init error: %v", err)
	}

	// Setup Gin
	router := gin.Default()
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
	})

	router.POST("/users", addUser)
	router.POST("/getusername", getUsername)
	router.POST("/createchat", createChat)
	router.GET("/search_users", searchUsers)
	router.POST("/store_public_key", storePublicKey)
	router.GET("/getinvites", getInvites)

	log.Println("Server started on :5000")
	router.Run(":5000")
}
