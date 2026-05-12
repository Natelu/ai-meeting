package services

func WriteArtifacts(meetingID, transcript, summary string, todos []string) string {
	return "s3://meeting-assets/mock/" + meetingID + "/summary.json"
}
