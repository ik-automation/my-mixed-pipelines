local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local annotation = grafana.annotation;

{
  deploymentsForEnvironment::
    annotation.datasource(
      'deploy',
      '-- Grafana --',
      enable=false,
      tags=['deploy', '$environment'],
      builtIn=1,
      iconColor='#96D98D',
    ),
  deploymentsForEnvironmentCanary::
    annotation.datasource(
      'canary-deploy',
      '-- Grafana --',
      enable=false,
      tags=['deploy', '${environment}-cny'],
      builtIn=1,
      iconColor='#FFEE52',
    ),
  deploymentsForK8sWorkloads::
    annotation.datasource(
      'k8s-workloads',
      '-- Grafana --',
      enable=false,
      tags=['k8s-workloads'],
      builtIn=1,
      iconColor='#316CE6',
    ),
  featureFlags::
    annotation.datasource(
      'feature-flags',
      '-- Grafana --',
      enable=false,
      tags=['feature-flag', '${environment}'],
      builtIn=1,
      iconColor='#CA95E5',
    ),
}
