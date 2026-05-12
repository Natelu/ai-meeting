package http

import (
	stdhttp "net/http"

	"github.com/ai-meeting/services/api/internal/integrations/livekit"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func registerWebhookRoutes(r *gin.Engine) {
	r.POST("/webhooks/livekit", func(c *gin.Context) {
		var payload livekit.RecordingEvent
		if err := c.ShouldBindJSON(&payload); err != nil {
			c.JSON(stdhttp.StatusBadRequest, gin.H{"error": "invalid livekit webhook payload"})
			return
		}
		if payload.Event != "egress_ended" {
			c.JSON(stdhttp.StatusOK, gin.H{"status": "ignored", "roomName": payload.RoomName})
			return
		}

		c.JSON(stdhttp.StatusAccepted, livekit.RecordingJob{
			JobID:    "job-" + uuid.NewString()[:8],
			RoomName: payload.RoomName,
			Status:   "accepted",
		})
	})
}
