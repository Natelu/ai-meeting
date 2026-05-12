package http

import (
	stdhttp "net/http"

	"github.com/ai-meeting/services/api/internal/service"
	"github.com/gin-gonic/gin"
)

type createMeetingRequest struct {
	Title      string `json:"title" binding:"required"`
	HostUserID string `json:"hostUserId" binding:"required"`
}

func registerMeetingRoutes(r *gin.Engine, meetingService service.MeetingService, exportService service.ExportService) {
	api := r.Group("/api")
	api.GET("/meetings", func(c *gin.Context) {
		c.JSON(stdhttp.StatusOK, gin.H{"meetings": meetingService.ListMeetings()})
	})
	api.POST("/meetings", func(c *gin.Context) {
		var req createMeetingRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(stdhttp.StatusBadRequest, gin.H{"error": "title and hostUserId are required"})
			return
		}

		c.JSON(stdhttp.StatusCreated, meetingService.CreateMeeting(req.Title, req.HostUserID))
	})
	api.GET("/meetings/:meetingId/summary", func(c *gin.Context) {
		c.JSON(stdhttp.StatusOK, meetingService.GetSummary(c.Param("meetingId")))
	})
	api.GET("/meetings/:meetingId/export", func(c *gin.Context) {
		if c.Query("format") == "json" {
			payload, err := exportService.JSON(c.Param("meetingId"))
			if err != nil {
				c.JSON(stdhttp.StatusInternalServerError, gin.H{"error": "export failed"})
				return
			}
			c.Data(stdhttp.StatusOK, "application/json; charset=utf-8", payload)
			return
		}
		c.Data(stdhttp.StatusOK, "text/markdown; charset=utf-8", []byte(exportService.Markdown(c.Param("meetingId"))))
	})
}
