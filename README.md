# 网络速度

一款轻量、原生的 macOS 状态栏网速监控工具。

## 功能

- 状态栏实时显示上传和下载速度
- 使用内核 `NET_RT_IFLIST2` 64 位接口计数器
- 汇总所有活动的物理网卡，排除回环、VPN 隧道和虚拟接口，兼容 Clash TUN/代理场景
- 双行固定宽度显示上传和下载速度
- 支持 0.5、1、2、5 秒刷新频率
- 支持登录时启动
- 原生 SwiftUI，无第三方依赖

## 隐私

应用只读取 macOS 已维护的网络接口累计字节数，不抓取数据包，不读取网站、域名、远程地址或网络内容，不上传任何统计数据，也不需要管理员权限。

## 系统要求

- macOS 13 或更高版本
- Apple Silicon 或 Intel Mac

## 构建

只需 Apple Command Line Tools，无需 Xcode 工程：

```sh
make test
make build
make verify
```

应用生成在：

```text
build/Network Speed.app
```

运行与发布：

```sh
make run
make release
```

公开分发时请通过 `APP_IDENTITY` 提供 Developer ID 签名身份，并按 Apple 要求完成公证；默认构建使用 ad-hoc 签名，适合本地运行。

## 开源说明

项目实现为独立代码。架构调研参考了 NetSpeedMonitor、Stats、NetBar 和 Netfluss；未复制 GPL 项目代码。
