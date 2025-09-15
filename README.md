📁 文件说明

server.cpp - C++服务器代码，使用OpenSSL实现TLS/SSL加密
client.py - Python客户端代码，使用ssl模块进行加密通信
setup.sh - 自动化设置脚本，包含安装、编译和证书生成

🚀 快速开始
方法1：使用自动化脚本（推荐）

```bash
# 1. 保存所有代码文件
#2. 给脚本执行权限
chmod +x setup.sh
#3.运行setup脚本
./setup.sh
#选择 1 进行完整安装
```

方法2：手动步骤
步骤1：安装依赖
Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y g++ make openssl libssl-dev python3
```

CentOS/RHEL:

```bash
sudo yum install -y gcc-c++ make openssl openssl-devel python3
```

macOS:

```bash 
brew install openssl@3 python3
```

步骤2：生成SSL证书

```bash
# 生成私钥
openssl genrsa -out server.key 2048
#生成自签名证书
openssl req -new -x509 -days 365 -key server.key -out server.crt \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=Test/OU=Dev/CN=localhost"
```

步骤3：编译C++服务器

```bash
# 编译服务器
g++ -std=c++11 -pthread -o server CPP_SERVE.cpp -lssl -lcrypto
```

步骤4：运行系统
终端1 - 启动服务器:

```bash
./server
```

终端2 - 启动客户端:

```bash
python3 PYTHON_CLIENT.py
```

💡 使用示例
交互模式

```bash
# 默认连接到localhost:8443
python3 PYTHON_CLIENT.py
```

指定服务器地址

```bash
python3 PYTHON_CLIENT.py --host 192.168.1.100 --port 8443
```

测试模式

```bash
# 自动发送测试消息
python3 PYTHON_CLIENT.py --mode test
```

快速测试

```bash
python3 quick_test.py
```

🔐 安全特性

TLS 1.2+ - 最低支持TLS 1.2版本
强加密套件 - 仅使用HIGH级别加密，禁用NULL、MD5、RC4
证书验证 - 支持证书验证（生产环境）
加密传输 - 所有数据都经过SSL/TLS加密

📝 重要说明

证书: 示例使用自签名证书（开发环境）。生产环境应使用CA签发的证书
端口: 默认使用8443端口，确保端口未被占用
防火墙: 如果有防火墙，需要开放8443端口
跨平台: 代码支持Linux、macOS，Windows需要调整头文件
