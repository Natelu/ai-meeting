package http

import (
	"fmt"
	stdhttp "net/http"
	"os"

	"github.com/ai-meeting/services/api/internal/integrations/livekit"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type joinMeetingRequest struct {
	UserID      string `json:"userId" binding:"required"`
	DisplayName string `json:"displayName" binding:"required"`
}

func registerLiveKitRoutes(r *gin.Engine) {
	api := r.Group("/api")
	api.POST("/meetings/:meetingId/join", func(c *gin.Context) {
		var req joinMeetingRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(stdhttp.StatusBadRequest, gin.H{"error": "userId and displayName are required"})
			return
		}

		meetingID := c.Param("meetingId")
		roomName := "meeting-" + meetingID
		c.JSON(stdhttp.StatusOK, livekit.JoinResponse{
			MeetingID:  meetingID,
			RoomName:   roomName,
			Token:      fmt.Sprintf("mock-token.%s.%s", roomName, req.UserID),
			LiveKitURL: envOrDefault("LIVEKIT_URL", "ws://localhost:7880"),
		})
	})

	api.POST("/meetings/:meetingId/recording/start", func(c *gin.Context) {
		meetingID := c.Param("meetingId")
		c.JSON(stdhttp.StatusAccepted, livekit.RecordingResponse{
			MeetingID: meetingID,
			RoomName:  "meeting-" + meetingID,
			EgressID:  "egress-" + uuid.NewString()[:8],
			Status:    "recording",
		})
	})
}

func envOrDefault(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}
