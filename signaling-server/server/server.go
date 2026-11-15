package server

import (
	"net/http"

	"signaling-server/config"
	"signaling-server/handler"
	"signaling-server/peer"
)

type Server struct {
	clientMgr *peer.ClientManager
	config    *config.Config
}

func NewServer(cfg *config.Config) *Server {
	return &Server{
		clientMgr: peer.NewClientManager(),
		config:    cfg,
	}
}

// ClientManager 返回客户端管理器实例
func (s *Server) ClientManager() *peer.ClientManager {
	return s.clientMgr
}

func (s *Server) Router() http.Handler {
	mux := http.NewServeMux()

	// 健康检查
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	// WebSocket 信令端点
	mux.HandleFunc("/ws", handler.NewSignalingHandler(s.clientMgr).HandleWebSocket)

	return corsMiddleware(mux)
}

// corsMiddleware CORS 中间件，支持前后端分离调试
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}
