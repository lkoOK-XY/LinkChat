package config

import (
	"fmt"
	"os"
)

type Config struct {
	Port int
	Host string
}

func Load() *Config {
	port := 8080
	if p := os.Getenv("PORT"); p != "" {
		if _, err := fmt.Sscanf(p, "%d", &port); err == nil {
			// 使用环境变量端口
		}
	}

	return &Config{
		Port: port,
		Host: "0.0.0.0",
	}
}
