package models

// BaseMessage 所有信令消息的基础字段
type BaseMessage struct {
	Type string `json:"type"`
}

// RegisterMessage 客户端注册消息（首条消息必须为注册）
type RegisterMessage struct {
	Type   string `json:"type"`
	PeerID string `json:"peer_id"`
}

// ConnectRequestMessage 连接请求
type ConnectRequestMessage struct {
	BaseMessage
	From string `json:"from,omitempty"`
	To   string `json:"to"`
}

// TargetMessage 含目标地址的消息
type TargetMessage struct {
	BaseMessage
	To string `json:"to"`
}

// SDPMessage SDP Offer/Answer 消息
type SDPMessage struct {
	TargetMessage
	SDP string `json:"sdp"`
}

// IceCandidateMessage ICE 候选消息
type IceCandidateMessage struct {
	TargetMessage
	Candidate map[string]interface{} `json:"candidate"`
}
