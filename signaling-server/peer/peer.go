package peer

import (
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

// Client 表示一个已连接的客户端
type Client struct {
	ID   string
	Conn *websocket.Conn
	Send chan []byte
	Mgr  *ClientManager
}

// ClientManager 管理所有在线客户端连接
type ClientManager struct {
	clients    map[string]*Client // peerID -> Client
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

func NewClientManager() *ClientManager {
	return &ClientManager{
		clients:    make(map[string]*Client),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

// Run 启动客户端管理循环
func (m *ClientManager) Run() {
	for {
		select {
		case client := <-m.register:
			m.mu.Lock()
			m.clients[client.ID] = client
			m.mu.Unlock()
			log.Printf("客户端 [%s] 已注册，当前在线: %d\n", client.ID, len(m.clients))

		case client := <-m.unregister:
			m.mu.Lock()
			if _, ok := m.clients[client.ID]; ok {
				delete(m.clients, client.ID)
				close(client.Send)
				log.Printf("客户端 [%s] 已断开，当前在线: %d\n", client.ID, len(m.clients))
			}
			m.mu.Unlock()
		}
	}
}

// Register 注册新客户端
func (m *ClientManager) Register(client *Client) {
	m.register <- client
}

// Unregister 注销客户端
func (m *ClientManager) Unregister(client *Client) {
	m.unregister <- client
}

// Get 根据 peerID 获取客户端
func (m *ClientManager) Get(peerID string) (*Client, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	c, ok := m.clients[peerID]
	return c, ok
}

// OnlineCount 返回在线数量
func (m *ClientManager) OnlineCount() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.clients)
}

// BroadcastExcept 向除指定客户端外的所有人广播
func (m *ClientManager) BroadcastExcept(excludeID string, message []byte) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for id, client := range m.clients {
		if id != excludeID {
			select {
			case client.Send <- message:
			default:
				go m.Unregister(client)
			}
		}
	}
}

// SendTo 向指定 peerID 发送消息
func (m *ClientManager) SendTo(peerID string, message []byte) bool {
	m.mu.RLock()
	client, ok := m.clients[peerID]
	m.mu.RUnlock()
	if !ok {
		return false
	}
	select {
	case client.Send <- message:
		return true
	default:
		return false
	}
}

// AllPeerIDs 返回所有在线 peerID
func (m *ClientManager) AllPeerIDs() []string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	ids := make([]string, 0, len(m.clients))
	for id := range m.clients {
		ids = append(ids, id)
	}
	return ids
}
