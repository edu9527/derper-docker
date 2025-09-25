# --- Builder Stage ---
# 使用一个特定的 Go 版本以保证构建的可复现性，如果要最新可以`golang:alpine`
FROM golang:1.25-alpine AS builder

# 设置工作目录
WORKDIR /app

# 设置 derper 版本参数
ARG DERP_VERSION=latest

# 安装 derper，CGO_ENABLED=0 确保生成静态链接的二进制文件
RUN CGO_ENABLED=0 go install tailscale.com/cmd/derper@${DERP_VERSION}


# --- Final Stage ---
# 使用轻量的 alpine 作为基础镜像
FROM alpine:latest

# 设置工作目录
WORKDIR /app

# 安装 derper 运行所必需的 ca-certificates (用于TLS/HTTPS)
# --no-cache 参数可以在同一层中添加并删除包索引，减小体积
RUN apk add --no-cache ca-certificates && \
    mkdir /app/certs && \
    rm -rf /var/cache/apk/*

# 设置环境变量，与原版保持一致
ENV DERP_DOMAIN your-hostname.com
ENV DERP_CERT_MODE letsencrypt
ENV DERP_CERT_DIR /app/certs
ENV DERP_ADDR :443
ENV DERP_STUN true
ENV DERP_STUN_PORT 3478
ENV DERP_HTTP_PORT 80
ENV DERP_VERIFY_CLIENTS false
ENV DERP_VERIFY_CLIENT_URL ""

# 从 builder 阶段拷贝编译好的二进制文件
# Go 默认会将 install 的文件放在 /go/bin/ 目录下
COPY --from=builder /go/bin/derper .

# 容器启动命令
# alpine 自带 sh, 可以解析环境变量
CMD /app/derper --hostname=$DERP_DOMAIN \
    --certmode=$DERP_CERT_MODE \
    --certdir=$DERP_CERT_DIR \
    --a=$DERP_ADDR \
    --stun=$DERP_STUN  \
    --stun-port=$DERP_STUN_PORT \
    --http-port=$DERP_HTTP_PORT \
    --verify-clients=$DERP_VERIFY_CLIENTS \
    --verify-client-url=$DERP_VERIFY_CLIENT_URL
