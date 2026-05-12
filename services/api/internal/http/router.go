package http

import (
	stdhttp "net/http"

	"github.com/ai-meeting/services/api/internal/service"
	"github.com/gin-gonic/gin"
)

func NewRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)

	meetingService := service.NewMeetingService()
	searchService := service.NewSearchService()
	exportService := service.NewExportService(meetingService)
	assetService := service.NewAssetService()

	r := gin.New()
	r.Use(gin.Recovery())

	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(stdhttp.StatusOK, gin.H{"status": "ok"})
	})

	r.GET("/metrics", func(c *gin.Context) {
		c.String(stdhttp.StatusOK, "app_up 1\nmeeting_mock_jobs_processing 1\n")
	})

	registerMeetingRoutes(r, meetingService, exportService)
	registerWebhookRoutes(r)
	registerLiveKitRoutes(r)
	registerSearchRoutes(r, searchService)
	registerAssetRoutes(r, assetService)
	registerJobRoutes(r)

	return r
}
