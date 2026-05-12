package service

import (
	"fmt"

	"github.com/ai-meeting/services/api/internal/domain"
)

type AssetAccess struct {
	MeetingID string `json:"meetingId"`
	AssetType string `json:"assetType"`
	URI       string `json:"uri"`
	Allowed   bool   `json:"allowed"`
}

type AssetService struct{}

func NewAssetService() AssetService {
	return AssetService{}
}

func (AssetService) Resolve(meetingID, assetType string, role domain.Role) (AssetAccess, bool) {
	if !domain.CanAccessAsset(role) {
		return AssetAccess{MeetingID: meetingID, AssetType: assetType, Allowed: false}, false
	}

	return AssetAccess{
		MeetingID: meetingID,
		AssetType: assetType,
		URI:       fmt.Sprintf("s3://meeting-assets/mock/%s/%s", meetingID, assetType),
		Allowed:   true,
	}, true
}
