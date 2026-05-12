package http

import (
	stdhttp "net/http"

	"github.com/ai-meeting/services/api/internal/service"
	"github.com/gin-gonic/gin"
)

func registerSearchRoutes(r *gin.Engine, searchService service.SearchService) {
	r.GET("/api/search", func(c *gin.Context) {
		c.JSON(stdhttp.StatusOK, gin.H{"results": searchService.Search(c.Query("q"))})
	})
}
