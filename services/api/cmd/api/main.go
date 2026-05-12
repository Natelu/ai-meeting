package main

import (
	"log"
	"os"

	apphttp "github.com/ai-meeting/services/api/internal/http"
)

func main() {
	addr := os.Getenv("API_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	if err := apphttp.NewRouter().Run(addr); err != nil {
		log.Fatal(err)
	}
}
