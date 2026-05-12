package http

import (
	stdhttp "net/http"

	"github.com/ai-meeting/services/api/internal/domain"
	"github.com/ai-meeting/services/api/internal/service"
	"github.com/gin-gonic/gin"
)

func registerAssetRoutes(r *gin.Engine, assetService service.AssetService) {
	r.GET("/api/meetings/:meetingId/assets/:assetType", func(c *gin.Context) {
		role := domain.Role(c.DefaultQuery("role", string(domain.RoleViewer)))
		asset, ok := assetService.Resolve(c.Param("meetingId"), c.Param("assetType"), role)
		if !ok {
			c.JSON(stdhttp.StatusForbidden, gin.H{
				"allowed": false,
				"error":   "role cannot access meeting asset",
			})
			return
		}

		c.JSON(stdhttp.StatusOK, asset)
	})
}
