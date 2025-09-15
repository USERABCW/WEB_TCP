// server.cpp - C++ TLS/SSL 加密服务器
#include <iostream>
#include <cstring>
#include <thread>
#include <vector>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>

#define PORT 8443
#define BUFFER_SIZE 4096

class SSLServer {
private:
    SSL_CTX* ctx;
    int server_fd;
    struct sockaddr_in address;
    std::vector<std::thread> client_threads;
    
public:
    SSLServer() : ctx(nullptr), server_fd(-1) {
        // 忽略SIGPIPE信号，防止客户端断开时服务器崩溃
        signal(SIGPIPE, SIG_IGN);
    }
    
    ~SSLServer() {
        cleanup();
    }
    
    // 初始化OpenSSL
    void init_openssl() {
        SSL_load_error_strings();
        OpenSSL_add_ssl_algorithms();
        SSL_library_init();
    }
    
    // 清理OpenSSL
    void cleanup_openssl() {
        EVP_cleanup();
    }
    
    // 创建SSL上下文
    SSL_CTX* create_context() {
        const SSL_METHOD* method;
        SSL_CTX* ctx;
        
        method = TLS_server_method();
        ctx = SSL_CTX_new(method);
        
        if (!ctx) {
            ERR_print_errors_fp(stderr);
            exit(EXIT_FAILURE);
        }
        
        // 设置加密套件优先级
        SSL_CTX_set_cipher_list(ctx, "HIGH:!aNULL:!MD5:!RC4");
        
        // 设置最低TLS版本
        SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION);
        
        return ctx;
    }
    
    // 配置SSL上下文
    void configure_context(SSL_CTX* ctx) {
        // 加载服务器证书
        if (SSL_CTX_use_certificate_file(ctx, "server.crt", SSL_FILETYPE_PEM) <= 0) {
            ERR_print_errors_fp(stderr);
            std::cerr << "错误：无法加载证书文件 server.crt" << std::endl;
            exit(EXIT_FAILURE);
        }
        
        // 加载私钥
        if (SSL_CTX_use_PrivateKey_file(ctx, "server.key", SSL_FILETYPE_PEM) <= 0) {
            ERR_print_errors_fp(stderr);
            std::cerr << "错误：无法加载私钥文件 server.key" << std::endl;
            exit(EXIT_FAILURE);
        }
        
        // 验证私钥
        if (!SSL_CTX_check_private_key(ctx)) {
            std::cerr << "错误：私钥与证书不匹配" << std::endl;
            exit(EXIT_FAILURE);
        }
    }
    
    // 创建socket
    int create_socket() {
        int sock;
        
        sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            perror("无法创建socket");
            exit(EXIT_FAILURE);
        }
        
        // 允许地址重用
        int opt = 1;
        if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt))) {
            perror("setsockopt失败");
            exit(EXIT_FAILURE);
        }
        
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = INADDR_ANY;
        address.sin_port = htons(PORT);
        
        if (bind(sock, (struct sockaddr*)&address, sizeof(address)) < 0) {
            perror("绑定失败");
            exit(EXIT_FAILURE);
        }
        
        if (listen(sock, 10) < 0) {
            perror("监听失败");
            exit(EXIT_FAILURE);
        }
        
        return sock;
    }
    
    // 处理客户端连接
    void handle_client(SSL* ssl) {
        char buffer[BUFFER_SIZE] = {0};
        int bytes;
        
        // 获取客户端信息
        std::cout << "客户端连接成功，使用加密套件: " << SSL_get_cipher(ssl) << std::endl;
        
        while ((bytes = SSL_read(ssl, buffer, sizeof(buffer) - 1)) > 0) {
            buffer[bytes] = '\0';
            std::cout << "收到加密消息: " << buffer << std::endl;
            
            // 构造响应
            std::string response = "服务器已收到: " + std::string(buffer);
            
            // 发送加密响应
            int send_bytes = SSL_write(ssl, response.c_str(), response.length());
            if (send_bytes <= 0) {
                int err = SSL_get_error(ssl, send_bytes);
                std::cerr << "SSL_write错误: " << err << std::endl;
                break;
            }
            
            // 如果收到"quit"，断开连接
            if (strcmp(buffer, "quit") == 0) {
                std::cout << "客户端请求断开连接" << std::endl;
                break;
            }
            
            memset(buffer, 0, sizeof(buffer));
        }
        
        if (bytes <= 0) {
            int err = SSL_get_error(ssl, bytes);
            if (err == SSL_ERROR_ZERO_RETURN) {
                std::cout << "客户端关闭了连接" << std::endl;
            } else {
                std::cerr << "SSL_read错误: " << err << std::endl;
            }
        }
        
        SSL_shutdown(ssl);
        SSL_free(ssl);
    }
    
    // 启动服务器
    void start() {
        init_openssl();
        ctx = create_context();
        configure_context(ctx);
        server_fd = create_socket();
        
        std::cout << "SSL/TLS服务器启动，监听端口 " << PORT << std::endl;
        std::cout << "等待客户端连接..." << std::endl;
        
        while (true) {
            struct sockaddr_in client_addr;
            socklen_t client_len = sizeof(client_addr);
            
            int client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
            if (client_fd < 0) {
                perror("接受连接失败");
                continue;
            }
            
            std::cout << "新客户端连接: " << inet_ntoa(client_addr.sin_addr) 
                      << ":" << ntohs(client_addr.sin_port) << std::endl;
            
            SSL* ssl = SSL_new(ctx);
            SSL_set_fd(ssl, client_fd);
            
            if (SSL_accept(ssl) <= 0) {
                ERR_print_errors_fp(stderr);
                SSL_shutdown(ssl);
                SSL_free(ssl);
                close(client_fd);
                continue;
            }
            
            // 创建新线程处理客户端
            client_threads.emplace_back(&SSLServer::handle_client, this, ssl);
            client_threads.back().detach();
        }
    }
    
    // 清理资源
    void cleanup() {
        if (server_fd >= 0) {
            close(server_fd);
        }
        if (ctx) {
            SSL_CTX_free(ctx);
        }
        cleanup_openssl();
    }
};

int main() {
    try {
        SSLServer server;
        server.start();
    } catch (const std::exception& e) {
        std::cerr << "服务器错误: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}

// ===================================
// Makefile 内容
/*
Makefile:

CXX = g++
CXXFLAGS = -std=c++11 -Wall -Wextra -pthread
LIBS = -lssl -lcrypto

TARGET = server
SOURCE = server.cpp

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SOURCE) $(LIBS)

clean:
	rm -f $(TARGET)

run: $(TARGET)
	./$(TARGET)

.PHONY: all clean run
*/
