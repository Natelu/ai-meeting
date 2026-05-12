package domain

type Role string

const (
	RoleAdmin  Role = "admin"
	RoleHost   Role = "host"
	RoleViewer Role = "viewer"
)

type User struct {
	ID          string `json:"id"`
	DisplayName string `json:"displayName"`
	Role        Role   `json:"role"`
}

func CanAccessAsset(role Role) bool {
	switch role {
	case RoleAdmin, RoleHost, RoleViewer:
		return true
	default:
		return false
	}
}
