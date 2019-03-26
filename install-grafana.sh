#!/bin/bash

set +e
echo "$0" | grep "\(/install.sh$\)\|\(/uninstall.sh$\)" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo -e "\nERROR! This script cannot be run stand-alone.\n"
  exit 1
fi
set -e

echo -e "\n#############"
echo -e   "# GRAFANA #"
echo -e   "#############\n"

install() {

  # Values to interpolate
  busybox_version=${BUSYBOX_IMAGE_VERSION:-1.30.1 }
  grafana_image_version=${GRAFANA_IMAGE_VERSION:-6.0.2}
  sidecar_image_version=${GRAFANA_SIDECAR_IMAGE_VERSION:-0.0.16}
  curl_image_version=${GRAFANA_CURL_IMAGE_VERSION:-3.1}
  grafana_instance_name=grafana
  grafana_chart_version=${GRAFANA_CHART_VERSION:-2.3.5}
  # Install Paths
  grafana_install_config=${install_config}/config/grafana
  mkdir -p ${grafana_install_config}

  grafana_config=${script_dir}/config/grafana

  # Interpolate k8s and helm resource declaration files for grafana chart

  eval "echo \"$(cat ${grafana_config}/chart-values.yml)\"" \
    > ${grafana_install_config}/chart-values.yml

  if [[ -z `echo -e "$helm_deployments" | awk "/^${grafana_instance_name}\s+/{ print \$1 }"` ]]; then
    echo -e "Installing grafana helm chart for '$grafana_instance_name'..."
    helm install \
      --values ${grafana_install_config}/chart-values.yml \
      --name $grafana_instance_name \
      --namespace $environment \
      --version $grafana_chart_version \
      releng/grafana
  else
    echo -e "Upgrading grafana helm chart for '$grafana_instance_name'..."
    helm upgrade \
      --values ${grafana_install_config}/chart-values.yml \
      --version $grafana_chart_version \
      $grafana_instance_name releng/grafana
  fi

  service_info=$(kubectl get service ${grafana_instance_name}-server --namespace ${environment} | tail -1)
  grafana_host=$(echo $service_info | awk '{ print $3 }')
  grafana_port=$(echo $service_info | awk '{ print substr($5,0,index($5,"/")-1) }')

}

uninstall() {

  set +e

  # Delete k8s and helm resources of grafana
  echo -e "\nDeleting grafana helm chart..."
  helm delete --purge grafana

  # Delete k8s and helm resources of grafana
  echo -e "\nDeleting grafana helm chart..."
  helm delete --purge grafana
  #kubectl delete persistentvolumeclaim grafana --namespace $environment
  #kubectl delete storageclass grafana

  set -e
}

case "$1" in
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  *)
    echo "ERROR! Invalid invocation of install script."
    exit 1
esac
