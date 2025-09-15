#!/bin/bash
# setup.sh - 设置和运行SSL/TLS加密通信系统

echo "=========================================="
echo "SSL/TLS 加密通信系统设置脚本"
echo "=========================================="

# 检查操作系统
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo "不支持的操作系统"
    exit 1
fi

# 1. 安装依赖
install_dependencies() {
    echo "正在安装依赖..."
    
    if [ "$OS" == "linux" ]; then
        # Ubuntu/Debian
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y g++ make openssl libssl-dev python3 python3-pip
        # CentOS/RHEL/Fedora
        elif command -v yum &> /dev/null; then
            sudo yum install -y gcc-c++ make openssl openssl-devel python3 python3-pip
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y gcc-c++ make openssl openssl-devel python3 python3-pip
        fi
    elif [ "$OS" == "macos" ]; then
        # macOS with Homebrew
        if ! command -v brew &> /dev/null; then
            echo "请先安装Homebrew"
            exit 1
        fi
        brew install openssl@3 python3
        echo "注意：macOS可能需要额外的链接器标志"
        echo "export LDFLAGS=\"-L/usr/local/opt/openssl@3/lib\""
        echo "export CPPFLAGS=\"-I/usr/local/opt/openssl@3/include\""
    fi
    
    # 安装Python SSL模块（通常已包含）
    pip3 install --upgrade pip
    
    echo "依赖安装完成!"
}

# 2. 生成SSL证书
generate_certificates() {
    echo ""
    echo "正在生成SSL证书..."
    
    # 生成私钥
    openssl genrsa -out server.key 2048
    
    # 生成证书签名请求（CSR）
    openssl req -new -key server.key -out server.csr -subj "/C=CN/ST=Beijing/L=Beijing/O=Test/OU=Dev/CN=localhost"
    
    # 生成自签名证书（有效期365天）
    openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
    
    # 生成CA证书（可选，用于客户端验证）
    openssl req -new -x509 -days 365 -key server.key -out ca.crt -subj "/C=CN/ST=Beijing/L=Beijing/O=Test CA/OU=Dev/CN=Test CA"
    
    # 清理CSR文件
    rm server.csr
    
    echo "证书生成完成!"
    echo "  - 私钥: server.key"
    echo "  - 证书: server.crt"
    echo "  - CA证书: ca.crt"
}

# 3. 编译C++服务器
compile_server() {
    echo ""
    echo "正在编译C++服务器..."
    
    # 创建Makefile
    cat > Makefile << 'EOF'
CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra -pthread
LIBS = -lssl -lcrypto

TARGET = server
SOURCE = CPP_SERVE.cpp

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SOURCE) $(LIBS)

clean:
	rm -f $(TARGET)

run: $(TARGET)
	./$(TARGET)

.PHONY: all clean run
EOF
    
    # 编译
    make clean
    make
    
    if [ -f "./server" ]; then
        echo "服务器编译成功!"
    else
        echo "服务器编译失败!"
        exit 1
    fi
}

# 4. 创建启动脚本
create_start_scripts() {
    echo ""
    echo "正在创建启动脚本..."
    
    # 创建服务器启动脚本
    cat > start_server.sh << 'EOF'
#!/bin/bash
echo "启动C++服务器..."
./server
EOF
    chmod +x start_server.sh
    
    # 创建客户端启动脚本
    cat > start_client.sh << 'EOF'
#!/bin/bash
echo "启动Python客户端..."
python3 PYTHON_CLIENT.py
EOF
    chmod +x start_client.sh
    
    # 创建测试脚本
    cat > test_connection.sh << 'EOF'
#!/bin/bash
echo "运行连接测试..."
python3 client.py --mode test
EOF
    chmod +x test_connection.sh
    
    echo "启动脚本创建完成!"
}

# 5. 显示使用说明
show_instructions() {
    echo ""
    echo "=========================================="
    echo "设置完成! 使用说明:"
    echo "=========================================="
    echo ""
    echo "1. 启动服务器（在终端1）:"
    echo "   ./start_server.sh"
    echo "   或"
    echo "   ./server"
    echo ""
    echo "2. 启动客户端（在终端2）:"
    echo "   ./start_client.sh"
    echo "   或"
    echo "   python3 client.py"
    echo ""
    echo "3. 客户端选项:"
    echo "   python3 client.py --host localhost --port 8443  # 指定服务器"
    echo "   python3 client.py --mode test                    # 测试模式"
    echo "   python3 client.py --verify                       # 验证证书"
    echo ""
    echo "4. 测试连接:"
    echo "   ./test_connection.sh"
    echo ""
    echo "5. 清理:"
    echo "   make clean                  # 清理编译文件"
    echo "   rm *.key *.crt *.csr       # 清理证书"
    echo ""
    echo "=========================================="
    echo "注意事项:"
    echo "- 服务器监听端口: 8443"
    echo "- 使用自签名证书（开发环境）"
    echo "- 客户端默认不验证证书"
    echo "- 输入 'quit' 退出客户端"
    echo "=========================================="
}

# 主菜单
main_menu() {
    echo ""
    echo "请选择操作:"
    echo "1) 完整安装（依赖+证书+编译）"
    echo "2) 仅生成证书"
    echo "3) 仅编译服务器"
    echo "4) 仅安装依赖"
    echo "5) 快速启动（假设已安装）"
    echo "6) 退出"
    echo ""
    read -p "选择 [1-6]: " choice
    
    case $choice in
        1)
            install_dependencies
            generate_certificates
            compile_server
            create_start_scripts
            show_instructions
            ;;
        2)
            generate_certificates
            ;;
        3)
            compile_server
            ;;
        4)
            install_dependencies
            ;;
        5)
            if [ ! -f "./server" ]; then
                echo "服务器未编译，正在编译..."
                compile_server
            fi
            if [ ! -f "./server.crt" ] || [ ! -f "./server.key" ]; then
                echo "证书不存在，正在生成..."
                generate_certificates
            fi
            create_start_scripts
            show_instructions
            ;;
        6)
            echo "退出"
            exit 0
            ;;
        *)
            echo "无效选择"
            exit 1
            ;;
    esac
}

# 运行主菜单
main_menu

# ===================================
# 快速测试脚本 (quick_test.py)
cat > quick_test.py << 'EOF'
#!/usr/bin/env python3
import socket
import ssl
import time

# 快速测试SSL连接
context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE

try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    ssl_sock = context.wrap_socket(sock)
    ssl_sock.settimeout(5)
    
    print("正在测试连接到 localhost:8443...")
    ssl_sock.connect(('localhost', 8443))
    print("✓ 连接成功!")
    
    # 发送测试消息
    test_msg = "Test message from quick test"
    ssl_sock.send(test_msg.encode())
    response = ssl_sock.recv(1024).decode()
    print(f"✓ 收到响应: {response}")
    
    ssl_sock.close()
    print("✓ 测试完成!")
    
except Exception as e:
    print(f"✗ 测试失败: {e}")
EOF
chmod +x quick_test.py

echo ""
echo "额外创建了 quick_test.py 用于快速测试连接"
