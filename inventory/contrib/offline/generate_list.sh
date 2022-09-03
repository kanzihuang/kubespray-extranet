#!/bin/bash
set -eo pipefail

CURRENT_DIR=$(cd $(dirname $0); pwd)
TEMP_DIR="${CURRENT_DIR}/temp"
INVENTORY_DIR="${CURRENT_DIR%/contrib/offline}"
REPO_ROOT_DIR="${INVENTORY_DIR%/inventory}/kubespray"
REGISTRY_HOST="docker.io/kanzihuang"
FILES_REPO="http://127.0.0.1:8080"

: ${DOWNLOAD_YML:="roles/download/defaults/main.yml"}

mkdir -p ${TEMP_DIR}

# generate all download files url template
grep 'download_url:' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
    | sed 's/^.*_url: //g;s/\"//g' > ${TEMP_DIR}/files.list.template

# generate group_var files-repo.yml
echo "---" > ${TEMP_DIR}/files-repo.yml
echo "files_repo: $FILES_REPO" >> ${TEMP_DIR}/files-repo.yml
sed -n "s@\(\w*_download_url\):\s*\"https://@\1: \"{{ files_repo }}/@p" ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
    | tr -d '\r' \
    >> ${TEMP_DIR}/files-repo.yml

# generate all images list template
sed -n '/^downloads:/,/download_defaults:/p' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
    | sed -n 's/repo: //p;s/tag: //p' | tr -d ' "\r' \
    | sed 'N;y#\n#:#'  > ${TEMP_DIR}/images.list.template

# generate group_var image-repo.yml
echo "---" > ${TEMP_DIR}/image-repo.yml
echo "registry_host: $REGISTRY_HOST" >> ${TEMP_DIR}/image-repo.yml
echo 'kube_image_repo: "{{ registry_host }}"' >> ${TEMP_DIR}/image-repo.yml
expr=$(sed -n -e '/^downloads:/,/download_defaults:/{/^\s*repo:/p}' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
    | sed -e 's@^\s*repo:@@; s@\W*@@g; s@^@/@; s@$@:/p;@;' \
    | sed -e ':BEGIN; N; y/\n/ /; bBEGIN' \
)
    # | tr '\r\n' ' \0' \

sed -n -e "$expr" ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
    | tr -d '\r' \
    | xargs -d '\n' -I {} ${CURRENT_DIR}/generate-image-path.sh ${REGISTRY_HOST} '{}' \
    >> ${TEMP_DIR}/image-repo.yml

# add kube-* images to images list template
# Those container images are downloaded by kubeadm, then roles/download/defaults/main.yml
# doesn't contain those images. That is reason why here needs to put those images into the
# list separately.
KUBE_IMAGES="kube-apiserver kube-controller-manager kube-scheduler kube-proxy"
for i in $KUBE_IMAGES; do
    echo "{{ kube_image_repo }}/$i:{{ kube_version }}" >> ${TEMP_DIR}/images.list.template
done

# run ansible to expand templates
/bin/cp ${CURRENT_DIR}/generate_list.yml ${INVENTORY_DIR}

(cd ${REPO_ROOT_DIR} && ansible-playbook $* "${INVENTORY_DIR}/generate_list.yml" && /bin/rm "${INVENTORY_DIR}/generate_list.yml") || exit 1
