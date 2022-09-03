# 公网创建 kubernetes 集群的主要问题

## 从github.com上下载软件安装包速度慢

```sh
$ wget --tries=1 https://github.com/etcd-io/etcd/releases/download/v3.5.3/etcd-v3.5.3-linux-amd64.tar.gz
Resolving github.com (github.com)... 20.205.243.166
Connecting to github.com (github.com)|20.205.243.166|:443... connected.
HTTP request sent, awaiting response... No data received.
Giving up.
```

## 无法从gcr.io和k8s.io上下载镜像

```sh
$ docker pull registry.k8s.io/pause:3.3
Error response from daemon: Head "https://k8s.gcr.io/v2/pause/manifests/latest": dial tcp 108.177.125.82:443: i/o timeout
```

## 云主机内网地址不支持跨云访问

### kubespray 参数 ip、access_ip 均使用内网 IP 地址

1. ansible logs：couldn't validate the identity of the API Server

```ansible
TASK [kubernetes/kubeadm : Join to cluster] ***********************************************************************************
fatal: [huawei01]: FAILED! => {"changed": false, "cmd": ["timeout", "-k", "120s", "120s", "/usr/local/bin/kubeadm", "join", "--config", "/etc/kubernetes/kubeadm-client.conf", "--ignore-preflight-errors=DirAvailable--etc-kubernetes-manifests", "--skip-phases="], "delta": "0:01:07.420820", "end": "2022-08-22 10:19:09.378700", "msg": "non-zero return code", "rc": 1, "start": "2022-08-22 10:18:01.957880", "stderr": "error execution phase preflight: couldn't validate the identity of the API Server: Get \"https://internal_ip_1:6443/api/v1/namespaces/kube-public/configmaps/cluster-info?timeout=10s\": net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)\nTo see the stack trace of this error execute with --v=5 or higher", "stderr_lines": ["error execution phase preflight: couldn't validate the identity of the API Server: Get \"https://internal_ip_1:6443/api/v1/namespaces/kube-public/configmaps/cluster-info?timeout=10s\": net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)", "To see the stack trace of this error execute with --v=5 or higher"], "stdout": "[preflight] Running pre-flight checks", "stdout_lines": ["[preflight] Running pre-flight checks"]}
```

### kubespray 参数 ip 使用内网IP地址、access_ip 使用公网 IP 地址

- ansible logs：Unable to start service etcd

```ansible
TASK [etcd : Configure | Ensure etcd is running] ******************************************************************************
fatal: [huawei03]: FAILED! => {"changed": false, "msg": "Unable to start service etcd: Job for etcd.service failed because thecontrol process exited with error code.\nSee \"systemctl status etcd.service\" and \"journalctl -xe\" for details.\n"}

$ sudo journalctl -xeu etcd
Aug 22 10:53:51 huawei03 etcd[384720]: {"level":"fatal","ts":"2022-08-22T10:53:51.356+0800","caller":"etcdmain/etcd.go:204","msg":"discovery failed","error":"--initial-cluster has etcd1=https://internal_ip_1:2380 but missing from --initial-advertise-peer-urls=https://public_ip_1:2380 (\"https://public_ip_1:2380\"(resolved from \"https://public_ip_1:2380\") != \"https://internal_ip_1:2380\"(resolved from \"https://internal_ip_1:2380\"))","stacktrace":"go.etcd.io/etcd/server/v3/etcdmain.startEtcdOrProxyV2\n\t/go/src/go.etcd.io/etcd/release/etcd/server/etcdmain/etcd.go:204\ngo.etcd.io/etcd/server/v3/etcdmain.Main\n\t/go/src/go.etcd.io/etcd/release/etcd/server/etcdmain/main.go:40\nmain.main\n\t/go/src/go.etcd.io/etcd/release/etcd/server/main.go:32\nruntime.main\n\t/go/gos/go1.16.15/src/runtime/proc.go:225"}
```

- ansible logs：Failed to update apt cache

```ansible
TASK [kubernetes/preinstall : Update package management cache (APT)] **********************************************************
fatal: [huawei01]: FAILED! => {"changed": false, "msg": "Failed to update apt cache: unknown reason"}
```

```sh
$ sudo apt update
Err:1 http://repo.huaweicloud.com/ubuntu focal InRelease
  Temporary failure resolving 'repo.huaweicloud.com'
```

- calico-node logs：i/o timeout

```sh
$ kubectl -n kube-system -it exec calico-node-fcvrf -- sh
Error from server: error dialing backend: dial tcp internal_ip_2:10250: i/o timeout

$ kubectl -n kube-system logs calico-node-fcvrf
Error from server: Get "https://internal_ip_2:10250/containerLogs/kube-system/calico-node-fcvrf/calico-node": dial tcp internal_ip_2:10250: i/o timeout
```

### kubespray 参数 ip、access_ip 均使用公网 IP 地址

- ansible logs：Stop if ip var does not match local ips

```ansible
TASK [kubernetes/preinstall : Stop if ip var does not match local ips] ********************************************************
fatal: [huawei03]: FAILED! => {
    "assertion": "(ip in ansible_all_ipv4_addresses) or (ip in ansible_all_ipv6_addresses)",
    "changed": false,
    "evaluated_to": false,
    "msg": "IPv4: '['internal_ip_1', 'internal_ip_1', '10.233.64.1']' and IPv6: '['fe80::a85c:b3ff:fe98:cb04', 'fe80::f816:3eff:fe82:8582', 'fe80::187d:bcff:fe48:a73c']' do not contain 'public_ip_1'"
}
```

- ansible logs：failed to fetch endpoints from etcd cluster member list

```ansible
TASK [etcd : Configure | Wait for etcd cluster to be healthy] *****************************************************************
fatal: [huawei03]: FAILED! => {"attempts": 4, "changed": false, "cmd": "set -o pipefail && /usr/local/bin/etcdctl endpoint --cluster status && /usr/local/bin/etcdctl endpoint --cluster health 2>&1 | grep -v 'Error: unhealthy cluster' >/dev/null", "delta": "0:00:05.017882", "end": "2022-08-22 11:31:01.474932", "msg": "non-zero return code", "rc": 1, "start": "2022-08-22 11:30:56.457050", "stderr": "{\"level\":\"warn\",\"ts\":\"2022-08-22T11:31:01.473+0800\",\"logger\":\"etcd-client\",\"caller\":\"v3/retry_interceptor.go:62\",\"msg\":\"retrying of unary invoker failed\",\"target\":\"etcd-endpoints://0xc000320fc0/public_ip_1:2379\",\"attempt\":0,\"error\":\"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connectionerror: desc = \\\"transport: Error while dialing dial tcp public_ip_1:2379: connect: connection refused\\\"\"}\nError: failed to fetch endpoints from etcd cluster member list: context deadline exceeded", "stderr_lines": ["{\"level\":\"warn\",\"ts\":\"2022-08-22T11:31:01.473+0800\",\"logger\":\"etcd-client\",\"caller\":\"v3/retry_interceptor.go:62\",\"msg\":\"retrying of unary invoker failed\",\"target\":\"etcd-endpoints://0xc000320fc0/public_ip_1:2379\",\"attempt\":0,\"error\":\"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \\\"transport: Error while dialing dial tcp public_ip_1:2379: connect: connection refused\\\"\"}", "Error: failed to fetch endpoints from etcd cluster member list: context deadline exceeded"], "stdout": "", "stdout_lines": []}
```

- kubelet logs：cannot assign requested address

```sh
$ sudo journalctl -xeu kubelet
Aug 22 16:02:50 huawei03 kubelet[551344]: E0822 16:02:50.710689  551344 server.go:166] "Failed to listen and serve" err="listen tcp public_ip_1:10250: bind: cannot assign requested address"
```

- nginx-proxy logs: connection refused

```sh
$ kubectl -n kube-system logs nginx-proxy-huawei01
Error from server: Get "https://public_ip_2:10250/containerLogs/kube-system/nginx-proxy-huawei01/nginx-proxy": dial tcp public_ip_2:10250: connect: connection refused
```

- calico node logs: calico/node is not ready

```sh
$ kubectl -n kube-system describe pods calico-node-c9pcp
Events:
  Warning  Unhealthy     14m (x2 over 14m)  kubelet            Readiness probe failed: calico/node is not ready: felix is not ready: readiness probe reporting 503
  Warning  NodeNotReady  11m                node-controller    Node is not ready

$ kubectl -n kube-system logs calico-node-c9pcp
Error from server: Get "https://public_ip_2:10250/containerLogs/kube-system/calico-node-c9pcp/calico-node": dial tcp public_ip_2:10250: connect: connection refused

$ kubectl -n kube-system describe pods calico-node-wlv7m
Events:
  Warning  Unhealthy  43s   kubelet            Readiness probe failed: calico/node is not ready: felix is not ready: Get "http://localhost:9099/readiness": dial tcp 127.0.0.1:9099: connect: connection refused
```

- apiserver logs: connection refused

```sh
$ sudo crictl logs e3b9e3fb453a4
W0822 10:36:46.478936       1 clientconn.go:1331] [core] grpc: addrConn.createTransport failed to connect to {public_ip_1:2379 public_ip_1 <nil> 0 <nil>}. Err: connection error: desc = "transport: Error while dialing dial tcp public_ip_1:2379: connect: connection refused".
```

## 参考链接

- [公网创建 kubernetes 集群的解决方案](solutions.md)