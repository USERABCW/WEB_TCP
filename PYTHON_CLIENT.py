#!/usr/bin/env python3
# client.py - Python TLS/SSL 加密客户端

import socket
import ssl
import sys
import os
from datetime import datetime

class SSLClient:
    def __init__(self, host='localhost', port=8443):
        self.host = host
        self.port = port
        self.context = None
        self.sock = None
        self.ssl_sock = None
        
    def create_ssl_context(self, verify_cert=False):
        """创建SSL上下文"""
        # 创建SSL上下文
        self.context = ssl.create_default_context()
        
        if verify_cert:
            # 验证服务器证书（生产环境）
            self.context.check_hostname = True
            self.context.verify_mode = ssl.CERT_REQUIRED
            # 如果有CA证书，加载它
            if os.path.exists('ca.crt'):
                self.context.load_verify_locations('ca.crt')
        else:
            # 开发环境：不验证证书（用于自签名证书）
            self.context.check_hostname = False
            self.context.verify_mode = ssl.CERT_NONE
        
        # 设置加密套件
        self.context.set_ciphers('HIGH:!aNULL:!MD5:!RC4')
        
        # 设置最低TLS版本
        self.context.minimum_version = ssl.TLSVersion.TLSv1_2
        
    def connect(self):
        """连接到服务器"""
        try:
            # 创建socket
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            
            # 包装成SSL socket
            self.ssl_sock = self.context.wrap_socket(
                self.sock, 
                server_hostname=self.host
            )
            
            # 连接到服务器
            print(f"正在连接到 {self.host}:{self.port}...")
            self.ssl_sock.connect((self.host, self.port))
            
            # 显示连接信息
            print(f"连接成功!")
            print(f"使用加密套件: {self.ssl_sock.cipher()}")
            print(f"SSL版本: {self.ssl_sock.version()}")
            
            # 获取服务器证书信息（如果可用）
            try:
                cert = self.ssl_sock.getpeercert()
                if cert:
                    print(f"服务器证书主题: {cert.get('subject', 'N/A')}")
            except:
                print("无法获取服务器证书信息（可能使用自签名证书）")
            
            print("-" * 50)
            
        except ssl.SSLError as e:
            print(f"SSL错误: {e}")
            sys.exit(1)
        except socket.error as e:
            print(f"Socket错误: {e}")
            sys.exit(1)
        except Exception as e:
            print(f"连接错误: {e}")
            sys.exit(1)
    
    def send_message(self, message):
        """发送加密消息"""
        try:
            # 发送消息
            self.ssl_sock.send(message.encode('utf-8'))
            
            # 接收响应
            response = self.ssl_sock.recv(4096).decode('utf-8')
            return response
        except ssl.SSLError as e:
            print(f"SSL传输错误: {e}")
            return None
        except Exception as e:
            print(f"发送消息错误: {e}")
            return None
    
    def interactive_mode(self):
        """交互模式"""
        print("进入交互模式（输入 'quit' 退出）")
        print("-" * 50)
        
        while True:
            try:
                # 获取用户输入
                message = input("请输入消息: ")
                
                if message.lower() == 'quit':
                    # 发送退出消息
                    self.ssl_sock.send(b'quit')
                    print("正在断开连接...")
                    break
                
                if not message:
                    continue
                
                # 记录发送时间
                send_time = datetime.now()
                
                # 发送消息并接收响应
                response = self.send_message(message)
                
                # 计算往返时间
                rtt = (datetime.now() - send_time).total_seconds() * 1000
                
                if response:
                    print(f"服务器响应: {response}")
                    print(f"往返时间: {rtt:.2f}ms")
                else:
                    print("未收到响应")
                
                print("-" * 50)
                
            except KeyboardInterrupt:
                print("\n用户中断")
                break
            except Exception as e:
                print(f"错误: {e}")
                break
    
    def send_test_messages(self):
        """发送测试消息"""
        test_messages = [
            "Hello, Server!",
            "这是一条加密消息",
            "1234567890",
            "!@#$%^&*()",
            "测试完成"
        ]
        
        print("发送测试消息...")
        print("-" * 50)
        
        for msg in test_messages:
            print(f"发送: {msg}")
            response = self.send_message(msg)
            if response:
                print(f"响应: {response}")
            else:
                print("未收到响应")
            print("-" * 50)
    
    def close(self):
        """关闭连接"""
        if self.ssl_sock:
            self.ssl_sock.close()
        if self.sock:
            self.sock.close()
        print("连接已关闭")
    
    def run(self, mode='interactive'):
        """运行客户端"""
        try:
            # 创建SSL上下文（开发环境不验证证书）
            self.create_ssl_context(verify_cert=False)
            
            # 连接到服务器
            self.connect()
            
            if mode == 'interactive':
                # 交互模式
                self.interactive_mode()
            elif mode == 'test':
                # 测试模式
                self.send_test_messages()
            
        finally:
            # 关闭连接
            self.close()

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='SSL/TLS加密客户端')
    parser.add_argument('--host', default='localhost', help='服务器地址')
    parser.add_argument('--port', type=int, default=8443, help='服务器端口')
    parser.add_argument('--mode', choices=['interactive', 'test'], 
                       default='interactive', help='运行模式')
    parser.add_argument('--verify', action='store_true', 
                       help='验证服务器证书')
    
    args = parser.parse_args()
    
    print("=" * 50)
    print("Python SSL/TLS 加密客户端")
    print("=" * 50)
    
    client = SSLClient(args.host, args.port)
    
    # 如果需要验证证书
    if args.verify:
        client.create_ssl_context(verify_cert=True)
    
    client.run(mode=args.mode)

if __name__ == "__main__":
    main()

# ===================================
# 简化版客户端（最小示例）
"""
simple_client.py - 最简化的SSL客户端

import socket
import ssl

# 创建SSL上下文（不验证证书）
context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE

# 创建socket并包装为SSL
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
ssl_sock = context.wrap_socket(sock)

# 连接到服务器
ssl_sock.connect(('localhost', 8443))
print("连接成功!")

# 发送和接收消息
while True:
    msg = input("消息: ")
    if msg == 'quit':
        break
    ssl_sock.send(msg.encode())
    response = ssl_sock.recv(1024).decode()
    print(f"响应: {response}")

ssl_sock.close()
"""
