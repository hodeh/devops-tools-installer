#!/bin/bash

set +e
echo "$0" | grep "\(/install.sh$\)\|\(/uninstall.sh$\)" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  echo -e "\nERROR! This script cannot be run stand-alone.\n"
  exit 1
fi
set -e

echo -e "\n#############"
echo -e   "# Prometheus #"
echo -e   "#############\n"

install() {

  # Values to interpolate
  prom_alert_manager_version=${PROM_ALERT_MGR_IMAGE_VERSION:-v0.16.1}
  prom_config_map_reload_version=${PROM_CONFIG_MAP_IMAGE_VERSION:-v0.2.2}
  busybox_version=${BUSYBOX_IMAGE_VERSION:-1.30.1 }
  prom_node_exporter_version=${PROM_NODE_EXPORTER:-v0.17.0}
  prom_kube_state_metrics_version=${PROM_KUBE_STATE_METRICS:-v1.5.0}
  prom_prometheus_version=${PROM_PROMETHEUS:-v2.8.0}
  prom_push_gateway_version=${PROM_PUSH_GATEWAY:-v0.7.0}
  prometheus_chart_version=${PROMETHEUS_CHART_VERSION:-8.9.0}
  prometheus_instance_name=prometheus

  # Install Paths
  prom_install_config=${install_config}/config/prometheus
  mkdir -p ${prom_install_config}

  prometheus_config=${script_dir}/config/prometheus

  # Interpolate k8s and helm resource declaration files for prom chart

  eval "echo \"$(cat ${prometheus_config}/chart-values.yml)\"" \
    > ${prom_install_config}/chart-values.yml

  if [[ -z `echo -e "$helm_deployments" | awk "/^${prometheus_instance_name}\s+/{ print \$1 }"` ]]; then
    echo -e "Installing prometheus helm chart for '$prometheus_instance_name'..."
    helm install \
      --values ${prom_install_config}/chart-values.yml \
      --name $prometheus_instance_name \
      --namespace $environment \
      --version $prometheus_chart_version \
      releng/prometheus
  else
    echo -e "Upgrading prometheus helm chart for '$prometheus_instance_name'..."
    helm upgrade \
      --values ${prom_install_config}/chart-values.yml \
      --version $prometheus_chart_version \
      $prometheus_instance_name releng/prometheus
  fi

  service_info=$(kubectl get service ${prometheus_instance_name}-master --namespace ${environment} | tail -1)
  prometheus_host=$(echo $service_info | awk '{ print $3 }')
  prometheus_port=$(echo $service_info | awk '{ print substr($5,0,index($5,"/")-1) }')
}

uninstall() {

  set +e

  # Delete k8s and helm resources of prometheus
  echo -e "\nDeleting prometheus helm chart..."
  helm delete --purge prometheus

  # Delete k8s and helm resources of prometheus
  echo -e "\nDeleting prometheus helm chart..."
  helm delete --purge prometheus
  #kubectl delete persistentvolumeclaim prometheus --namespace $environment
  #kubectl delete storageclass prometheus

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
