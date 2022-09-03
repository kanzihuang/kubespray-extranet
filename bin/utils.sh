inventory_dir=$(cd "$(dirname $0)/../inventory/" && pwd)

function kubespray-run() {
  docker run --rm -it --mount type=bind,source="${inventory_dir}",dst=/inventory \
    --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
    docker.io/kanzihuang/kubespray:v2.19.0 "$@"
}

function docker-ansible() {
  kubespray-run ansible "${$@}"
}

function docker-ansible-playbook() {
  kubespray-run ansible-playbook "$@"
}
