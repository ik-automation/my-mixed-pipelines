local kubernetes = import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet';

local mixin = kubernetes {
  _config+:: {
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    cadvisorSelector: 'job="kubelet"',
    nodeExporterSelector: 'job="node-exporter"',
    kubeletSelector: 'job="kubelet"',
    grafanaK8s+:: {
      dashboardNamePrefix: '',
      dashboardTags: ['kubernetes', 'infrastucture'],
    },
    showMultiCluster: true,
  },
};

// Perform custom modifications to the dashboard to suit the GitLab Grafana deployment
{
  [std.strReplace(x, 'k8s-', '')]: mixin.grafanaDashboards[x] {
    uid: null,
    timezone: 'UTC',
  }
  for x in std.objectFields(mixin.grafanaDashboards)
}
