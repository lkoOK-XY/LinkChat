package main

import (
	"fmt"
	"log"
	"net/http"
	"signaling-server/config"
	"signaling-server/server"
)

func main() {
	// 加载配置
	cfg := config.Load()

	// 创建 WebSocket 服务
	srv := server.NewServer(cfg)

	// 启动客户端管理器（处理注册/注销）
	go srv.ClientManager().Run()

	// 启动 HTTP 服务（含 WebSocket 端点）
	addr := fmt.Sprintf(":%d", cfg.Port)
	log.Printf("信令服务器启动，监听 %s", addr)
	log.Fatal(http.ListenAndServe(addr, srv.Router()))
}
