package handler

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"signaling-server/models"
	"signaling-server/peer"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// 生产环境应做更严格的来源检查
		return true
	},
}

type SignalingHandler struct {
	clientMgr *peer.ClientManager
}

func NewSignalingHandler(mgr *peer.ClientManager) *SignalingHandler {
	return &SignalingHandler{clientMgr: mgr}
}

// HandleWebSocket 处理 WebSocket 连接升级与消息分发
func (h *SignalingHandler) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket 升级失败: %v", err)
		return
	}

	// 等待第一条注册消息获取 peerID
	var regMsg models.RegisterMessage
	err = conn.ReadJSON(&regMsg)
	if err != nil || regMsg.Type != "register" || regMsg.PeerID == "" {
		conn.WriteJSON(map[string]string{"error": "需要先发送注册消息"})
		conn.Close()
		return
	}

	client := &peer.Client{
		ID:   regMsg.PeerID,
		Conn: conn,
		Send: make(chan []byte, 256),
		Mgr:  h.clientMgr,
	}

	h.clientMgr.Register(client)

	// 启动读写协程
	go h.writePump(client)
	go h.readPump(client)
}

// readPump 读取客户端消息并转发
func (h *SignalingHandler) readPump(client *peer.Client) {
	defer func() {
		h.clientMgr.Unregister(client)
		client.Conn.Close()
	}()

	for {
		var rawMsg json.RawMessage
		if err := client.Conn.ReadJSON(&rawMsg); err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("读取错误 [%s]: %v", client.ID, err)
			}
			break
		}

		// 解析基础字段以确定消息类型
		var base models.BaseMessage
		if err := json.Unmarshal(rawMsg, &base); err != nil {
			continue
		}

		switch base.Type {
		case "connect_request":
			h.handleConnectRequest(client, rawMsg)

		case "accepted":
			h.handleAccepted(client, rawMsg)

		case "offer":
			h.handleOffer(client, rawMsg)

		case "answer":
			h.handleAnswer(client, rawMsg)

		case "ice_candidate":
			h.handleIceCandidate(client, rawMsg)

		case "disconnect":
			h.handleDisconnect(client, rawMsg)

		default:
			log.Printf("未知消息类型 [%s]: %s", client.ID, base.Type)
		}
	}
}

// writePump 将消息写入客户端连接
func (h *SignalingHandler) writePump(client *peer.Client) {
	defer client.Conn.Close()

	for msg := range client.Send {
		if err := client.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			break
		}
	}
}

// handleConnectRequest 处理连接请求
func (h *SignalingHandler) handleConnectRequest(from *peer.Client, rawMsg json.RawMessage) {
	var req models.ConnectRequestMessage
	json.Unmarshal(rawMsg, &req)

	target, exists := h.clientMgr.Get(req.To)
	if !exists {
		from.Send <- h.errorMsg("目标用户不在线")
		return
	}

	// 转发连接请求给目标
	forwardData, _ := json.Marshal(map[string]interface{}{
		"type": "connect_request",
		"from": from.ID,
	})
	log.Printf("正在向 [%s] 转发连接请求，数据: %s", req.To, string(forwardData))
	target.Send <- forwardData
	log.Printf("[%s] -> [%s]: 连接请求（已写入发送队列）", from.ID, req.To)
}

// handleAccepted 转发接受连接消息（被连接方 → 发起方）
func (h *SignalingHandler) handleAccepted(from *peer.Client, rawMsg json.RawMessage) {
	var msg models.TargetMessage
	json.Unmarshal(rawMsg, &msg)

	target, exists := h.clientMgr.Get(msg.To)
	if !exists {
		return
	}

	forwardData, _ := json.Marshal(map[string]interface{}{
		"type": "accepted",
		"from": from.ID,
	})
	target.Send <- forwardData
	log.Printf("[%s] -> [%s]: 接受连接", from.ID, msg.To)
}

// handleOffer 转发 SDP Offer
func (h *SignalingHandler) handleOffer(from *peer.Client, rawMsg json.RawMessage) {
	var msg models.SDPMessage
	json.Unmarshal(rawMsg, &msg)

	target, exists := h.clientMgr.Get(msg.To)
	if !exists {
		from.Send <- h.errorMsg("目标用户不在线")
		return
	}

	forwardData, _ := json.Marshal(map[string]interface{}{
		"type": "offer",
		"from": from.ID,
		"sdp":  msg.SDP,
	})
	target.Send <- forwardData
}

// handleAnswer 转发 SDP Answer
func (h *SignalingHandler) handleAnswer(from *peer.Client, rawMsg json.RawMessage) {
	var msg models.SDPMessage
	json.Unmarshal(rawMsg, &msg)

	target, exists := h.clientMgr.Get(msg.To)
	if !exists {
		return
	}

	forwardData, _ := json.Marshal(map[string]interface{}{
		"type": "answer",
		"from": from.ID,
		"sdp":  msg.SDP,
	})
	target.Send <- forwardData
}

// handleIceCandidate 转发 ICE 候选
func (h *SignalingHandler) handleIceCandidate(from *peer.Client, rawMsg json.RawMessage) {
	var msg models.IceCandidateMessage
	json.Unmarshal(rawMsg, &msg)

	target, exists := h.clientMgr.Get(msg.To)
	if !exists {
		return
	}

	forwardData, _ := json.Marshal(map[string]interface{}{
		"type":      "ice_candidate",
		"from":      from.ID,
		"candidate": msg.Candidate,
	})
	target.Send <- forwardData
}

// handleDisconnect 转发断开通知
func (h *SignalingHandler) handleDisconnect(from *peer.Client, rawMsg json.RawMessage) {
	var msg models.TargetMessage
	json.Unmarshal(rawMsg, &msg)

	if target, exists := h.clientMgr.Get(msg.To); exists {
		forwardData, _ := json.Marshal(map[string]interface{}{
			"type": "disconnect",
			"from": from.ID,
		})
		target.Send <- forwardData
	}
}

func (h *SignalingHandler) errorMsg(msg string) []byte {
	data, _ := json.Marshal(map[string]string{"error": msg})
	return data
}
