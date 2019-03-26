#!/bin/bash

script_dir=$(cd $(dirname $0) && pwd)

set -e

usage () {
    echo -e "\nUSAGE: download.sh [ -r|--registry <REGISTRY_DNS> ] \\"
    echo -e "                   [ -u|--user <USER_NAME> -p|--password <PASSWORD> ] \\" 
    echo -e "                   [ -c|--clean ] [ -d|--download-only ]\n"
    echo -e "    This utility will download all required artifacts to set up the devops tools. It will"
    echo -e "    upload them to a private registry such as Harbor. Downloaded images and charts will"
    echo -e "    be saved locally and re-used for off-line installs.\n"
    echo -e "    -r|--registry <REGISTRY_DNS>    The FQDN or IP of the registry."
    echo -e "    -u|--user <USER_NAME>           The name of the user to use to authenticate with private registry"
    echo -e "    -p|--password <PASSWORD>        The password of the user."
    echo -e "    -c|--clean                      Upload clean images."
    echo -e "    -d|--download-only              Do not connect and upload to a private registy. Download only.\n"
    echo -e "    Options --registry, --user and --password are required if --download-only flag is not provided\n"
}

download_images() {

  local image_list=$1
  local image_download_dir=$2
  local upload_path=$3
  local clean=$4

  docker_images=$(docker images)

  for d in $(echo $image_list); do

    local dd=${d%:*}
    local n=${dd##*/}
    local v=${d#*:}
    local a=${image_download_dir}/${n}_${v}.tar

    [[ -z $clean ]] || \
      echo -e "$docker_images" \
        | awk "/\/$n\s+/{ print \$3 }" \
        | uniq \
        | xargs docker rmi -f

    if [[ -e $a ]]; then
      echo -e "\n*** Loading image $n version $v from download archive..."
      docker load --input $a
    else
      echo -e "\n*** Pulling image from $d..."
      docker pull $d
      docker save --output $a $d
    fi

    if [[ -z $download_only ]]; then
      # Upload docker images to private registry
      #
      # If the private registry is using a self-signed certificate 
      # make sure it is set as an insecure registry at docker startup

      echo -e "\n*** Uploading image $n version $v..."
      docker tag $d ${upload_path}/${n}:${v}
      docker push ${upload_path}/${n}:${v}
    fi
  done
}

download_charts() {

  local chart_list=$1
  local chart_download_dir=$2
  local upload_registry=$3
  local registry_ca_cert_file=$4
  local clean=$5

  for c in $(echo $chart_list); do

    local cc=${c%:*}
    local n=${cc##*/}
    local v=${c#*:}
    local a=${chart_download_dir}/${n}-${v}.tgz

    [[ -z $clean ]] || \
      rm -f $a
    if [[ ! -e $a ]]; then
      echo -e "\n*** Downloading chart $n version $v..."
      helm --destination ${chart_download_dir} fetch $cc --version $v
    fi

    if [[ -z $download_only ]]; then
      echo -e "\n*** Uploading chart $n version $v..."
      helm push \
        --ca-file $registry_ca_cert_file \
        $a $upload_registry
    fi
  done

  helm repo update
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    '-?'|--help|help)
      usage
      exit 0
      ;;
    -v|--debug)
      set -x
      ;;
    -r|--registry)
      registry=$2
      shift
      ;;
    -u|--user)
      user=$2
      shift
      ;;
    -p|--password)
      password=$2
      shift
      ;;
    -c|--clean)
      clean=1
      ;;
    -d|--download-only)
      download_only=1
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z $download_only \
  && ( -z $registry \
  || -z $user \
  || -z $password ) ]]; then

  usage
  exit 1
fi

ca_cert_file=${script_dir}/.certs/ca.crt
if [[ ! -e $ca_cert_file ]]; then
  echo -e "\nERROR: Please provide a CA cert file at:"
  echo -e "       $ca_cert_file"
  echo -e "       to validate self-signed TLS end-points.\n"
  exit 1
fi

# Login to private registry
if [[ -z $download_only ]]; then
  echo -e "Logging in to private registry '$registry' as user '$user'..."
  docker login --username $user --password $password $registry
fi

# Download and upload docker images

tiller_version=${TILLER_VERSION:-v2.13.0}
nginx_ingress_controller_version=${NGINX_INGRESS_CONTROLLER_VERSION:-0.23.0}
defaultbackend_version=${DEFAULTBACKEND_VERSION:-1.4}
alpine_image_version=${ALPINE_IMAGE_VERSION:-3.8}
busybox_image_version=${BUSYBOX_IMAGE_VERSION:-1.30.1 }
concourse_image_version=${CONCOURSE_IMAGE_VERSION:-5.0.0}
postgresql_image_version=${POSTGRESQL_IMAGE_VERSION:-11.2.0}
artifactory_image_version=${ARTIFACTORY_IMAGE_VERSION:-6.8.7}
artifactory_nginx_image_version=${ARTIFACTORY_NGINX_IMAGE_VERSION:-6.8.7}
redis_image_version=${REDIS_IMAGE_VERSION:-5.0.4}
minio_image_version=${MINIO_IMAGE_VERSION:-RELEASE.2019-03-20T22-38-47Z}
minio_mc_image_version=${MINIO_MC_IMAGE_VERSION:-RELEASE.2019-03-20T21-29-03Z}
halyard_image_version=${HALYARD_IMAGE_VERSION:-1.17.0}
prom_alert_mgr_version=${PROM_ALERT_MGR_IMAGE_VERSION:-v0.16.1}
prom_config_map_reload_version=${PROM_CONFIG_MAP_IMAGE_VERSION:-v0.2.2}
prom_kube_state_metrics=${PROM_KUBE_STATE_METRICS:-v1.5.0}
prom_node_exporter=${PROM_NODE_EXPORTER:-v0.17.0}
prom_prometheus=${PROM_PROMETHEUS:-v2.8.0}
prom_push_gateway=${PROM_PUSH_GATEWAY:-v0.7.0}
grafana_image_version=${GRAFANA_IMAGE_VERSION:-6.0.2}
grafana_sidecar_image_version=${GRAFANA_SIDECAR_IMAGE_VERSION:-0.0.16}
grafana_appropriate_curl_image_version=${GRAFANA_CURL_IMAGE_VERSION:-3.1}

image_download_dir=${script_dir}/.downloads/images
mkdir -p $image_download_dir

download_images \
  "
    gcr.io/kubernetes-helm/tiller:${tiller_version}
    quay.io/kubernetes-ingress-controller/nginx-ingress-controller:${nginx_ingress_controller_version}
    k8s.gcr.io/defaultbackend:${defaultbackend_version}
    alpine:${alpine_image_version}
    busybox:${busybox_image_version}
    concourse/concourse:${concourse_image_version}
    bitnami/postgresql:${postgresql_image_version}
    bitnami/minideb:latest
    docker.bintray.io/jfrog/artifactory-oss:${artifactory_image_version}
    docker.bintray.io/jfrog/nginx-artifactory-pro:${artifactory_nginx_image_version}
    bitnami/redis:${redis_image_version}
    minio/minio:${minio_image_version}
    minio/mc:${minio_mc_image_version}
    gcr.io/spinnaker-marketplace/halyard:${halyard_image_version}
    prom/alertmanager:${prom_alert_mgr_version}
    jimmidyson/configmap-reload:${prom_config_map_reload_version}
    quay.io/coreos/kube-state-metrics:${prom_kube_state_metrics}
    prom/node-exporter:${prom_node_exporter}
    prom/prometheus:${prom_prometheus}
    prom/pushgateway:${prom_push_gateway}
    kiwigrid/k8s-sidecar:${grafana_sidecar_image_version}
    grafana/grafana:${grafana_image_version}
    appropriate/curl:${grafana_appropriate_curl_image_version}

  " \
  "$image_download_dir" \
  "${registry}/releng" \
  "$clean"

# Download and upload helm charts

nginx_ingress_chart_version=${NGINX_INGRESS_CHART_VERSION:-1.4.0}
concourse_chart_version=${CONCOURSE_CHART_VERSION:-5.0.0}
postgresql_chart_version=${POSTGRESQL_CHART_VERSION:-3.15.0}
artifactory_chart_version=${ARTIFACTORY_CHART_VERSION:-7.12.16}
redis_chart_version=${REDIS_CHART_VERSION:-6.4.3}
minio_chart_version=${MINIO_CHART_VERSION:-2.4.9}
spinnaker_chart_version=${SPINNAKER_CHART_VERSION:-1.8.1}
prometheus_chart_version=${PROMETHEUS_CHART_VERSION:-8.9.0}
grafana_chart_version=${GRAFANA_CHART_VERSION:-2.3.5}

helm init --client-only >/dev/null 2>&1
helm repo add jfrog https://charts.jfrog.io/
if [[ -z $download_only ]]; then
  helm repo add \
    --ca-file $ca_cert_file --username $user --password $password \
    releng https://${registry}/chartrepo/releng
fi
helm repo update

chart_download_dir=${script_dir}/.downloads/charts
mkdir -p $chart_download_dir

download_charts \
  "
    stable/nginx-ingress:${nginx_ingress_chart_version}
    stable/concourse:${concourse_chart_version}
    stable/concourse:${concourse_chart_version}
    stable/postgresql:${postgresql_chart_version}
    jfrog/artifactory:${artifactory_chart_version}
    stable/redis:${redis_chart_version}
    stable/minio:${minio_chart_version}
    stable/spinnaker:${spinnaker_chart_version}
    stable/prometheus:${prometheus_chart_version}
    stable/grafana:${grafana_chart_version}
  " \
  "$chart_download_dir" \
  "releng" \
  "$ca_cert_file" \
  "$clean"
