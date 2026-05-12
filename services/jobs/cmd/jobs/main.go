package main

import (
	"encoding/json"
	"log"

	"github.com/ai-meeting/services/jobs/internal/tasks"
)

func main() {
	result := tasks.ProcessPostMeetingAsset("meeting-demo", "/data/mock/audio.wav")
	encoded, err := json.Marshal(result)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("mock post-meeting job complete: %s", encoded)
}
