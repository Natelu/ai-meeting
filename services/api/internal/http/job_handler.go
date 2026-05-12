package http

import (
	stdhttp "net/http"

	"github.com/gin-gonic/gin"
)

func registerJobRoutes(r *gin.Engine) {
	r.GET("/api/jobs/:jobId", func(c *gin.Context) {
		c.JSON(stdhttp.StatusOK, gin.H{
			"jobId":   c.Param("jobId"),
			"status":  "processing",
			"stage":   "summary",
			"message": "mock pipeline is generating summary and todos",
		})
	})
}
