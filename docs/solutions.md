# 公网创建 kubernetes 集群的解决方案

## 如何解决从github.com上下载软件安装包速度慢的问题

创建kubespray-file-server镜像，将kubespary需要的软件包打包存放到镜像中，将镜像推送到hub.docker.io（阿里云和腾讯云使用云厂商镜像加速即可，华为云需要推送到华为云容器镜像服务器），然后在云主机上运行kubespray-file-server容器提供下载服务。
[构建kubespray-file-server镜像](https://github.com/kanzihuang/docker-images)

## 如何解决无法从gcr.io和k8s.io上下载镜像的问题

将kubespray需要的镜像推送到hub.docker.io（阿里云和腾讯云使用云厂商镜像加速即可，华为云需要推送到华为云容器镜像服务器）。
[复制kubespray需要的镜像hub.docker.io](https://github.com/kanzihuang/mirror-images-action)

## 如何解决云主机内网地址不支持跨云访问的问题

云主机内网地址不支持跨云访问的问题，可采用云主机创建虚拟网卡模拟公网地址的方式解决，具体解决方案如下。

### 配置主机网络

1. 获取IP地址

```sh
internal_ip=a.b.c.d
public_ip=a.b.c.d
```

1. 创建虚拟网卡

由于内网地址不可达，创建虚拟网卡配置公网IP地址，kube-cluster通过公网IP地址实现节点互通。

```sh
sudo ip link add dummy-pub0 type dummy
sudo ip addr add $public_ip/32 dev dummy-pub0
```

### 配置 NAT 转换

- calico node 创建的 vxlan，tunnel 两端的 IP 地址均被设置为公网 IP 地址。由于云厂商通过 NAT 转换暴露公网 IP 地址，由于 vxlan 封装的数据包源地址为公网 IP 地址，该数据包被云厂商 NAT 转换设备拦截，导致 vxlan 数据传输失败。为解决这个问题，在云主机上通过 iptables 将源地址从公网地址转换为内网地址。

- 由于 etcd 节点在内网 IP 地址上监听数据包，而本地客户端通过公网 IP地址连接 etcd 服务，导致网络连接被拒绝。为解决这个问题，在云主机上通过 iptables 将目的地址从公网地址转换为内网地址。

```sh
sudo iptables -t nat -I POSTROUTING -s $public_ip/32 -j SNAT --to-source $internal_ip
sudo iptables -t nat -I OUTPUT -d $public_ip/32 -j DNAT --to-destination $internal_ip
```

## 配置 kubespray inventory 变量

1. 配置主机地址

- 为解决内网 IP 地址不可达的问题，将 ansible_host、ip、access_ip 均设置为节点公网 IP 地址。

- 由于 etcd 仅监听公网 IP 地址，而云厂商 NAT 设备接收数据包时将公网 IP 地址转换为内网 IP 地址，导致 kubelet 拒绝连接。为解决这个问题，将 etcd 监听地址设置为**内网** IP 地址。

```yml : hosts.yml
all:
  hosts:
    node01:
      ansible_host: a.b.c.d         # 公网地址
      ip: a.b.c.d                   # 公网地址
      access_ip: a.b.c.d            # 公网地址
      etcd_address: a.b.c.d         # 内网地址
    node02:
      ansible_host: a.b.c.d         # 公网地址
      ip: a.b.c.d                   # 公网地址
      access_ip: a.b.c.d            # 公网地址
```

2. 配置监听地址

- 由于 kubelet 将公网 IP 地址设置为监听地址，而云厂商 NAT 设备接收数据包时将公网 IP 地址转换为内网 IP 地址，导致 kubelet 拒绝连接。为解决这个问题，将 kubelet 监听地址设置为 0.0.0.0，监听云主机上所有 IP 地址。

```yml : group_vars/k8s_cluster/k8s-cluster.yml
## bind address for kubelet. Set to 0.0.0.0 to listen on all interfaces
kubelet_bind_address: "0.0.0.0"
```

## 参考链接

- [公网创建 kubernetes 集群的主要问题](problems.md)
