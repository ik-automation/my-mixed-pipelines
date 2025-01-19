// kubeLabelSelector allows services in the metrics-catalog
// to define a set of kubernetes resources that belong to the
// service.
// ```jsonnet
// kubeConfig: {
//    labelSelectors: kubeLabelSelectors(
//      ingressSelector={ namespace: "monitoring" },
//    )
// },
// ```
// In the example above, the service will include all ingresses in the
// namespace "monitoring". These will be included for monitoring, alerting
// and charting purposes.
//
// This functionality relies on kube_state_metrics, which will create
// kube_<resource>_label metrics for each resource. The metrics have
// label_<kube_label> labels on them. This allows us to match Kubernetes
// label to services, using PromQL selector syntax.
//
// Ideally, these selectors will be standardized on `type`, `shard`, etc
// but there are still a lot of exceptions, and this appproach
// allows us to flexibly include and exclude resources.
//
// See https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/15208

local objects = import 'utils/objects.libsonnet';

// Special default value placeholder
local defaultValue = { __default__: true };

local identityFieldsForKubeMetricTypes = {
  pod: 'pod',
  hpa: 'horizontalpodautoscaler',
  node: 'node',
  ingress: 'ingress',
  deployment: 'deployment',
};

local kubeSelectorToPromSelector(kubeMetricType, selector) =
  local identityField = identityFieldsForKubeMetricTypes[kubeMetricType];

  objects.mapKeyValues(
    function(key, value)
      // Namespace labels don't need a prefix
      // All kube_*_label metrics have a namespace attribute
      if key == 'namespace' then
        [key, value]
      // For each kube_metric_type (pod, ingress, etc) there is an identity label:
      // we don't need to prefix this with `label_`
      else if key == identityField then
        [key, value]
      else
        ['label_' + key, value],
    selector
  );

function(
  podSelector=defaultValue,
  hpaSelector=defaultValue,
  nodeSelector=null,  // by default we don't define service fleets
  ingressSelector=defaultValue,
  deploymentSelector=defaultValue,

  podStaticLabels=defaultValue,
  hpaStaticLabels=defaultValue,
  nodeStaticLabels=defaultValue,
  ingressStaticLabels=defaultValue,
  deploymentStaticLabels=defaultValue,
)
  {
    init(type, tier)::
      local defaultSelector = { type: type };
      local defaultStaticLabels = { type: type, tier: tier };

      {
        pod: if podSelector == defaultValue then defaultSelector else podSelector,
        hpa: if hpaSelector == defaultValue then defaultSelector else hpaSelector,
        node: nodeSelector,
        ingress: if ingressSelector == defaultValue then defaultSelector else ingressSelector,
        deployment: if deploymentSelector == defaultValue then defaultSelector else deploymentSelector,

        staticLabels:: {
          pod: if podStaticLabels == defaultValue then defaultStaticLabels else podStaticLabels,
          hpa: if hpaStaticLabels == defaultValue then defaultStaticLabels else hpaStaticLabels,
          node: if nodeStaticLabels == defaultValue then defaultStaticLabels else nodeStaticLabels,
          ingress: if ingressStaticLabels == defaultValue then defaultStaticLabels else ingressStaticLabels,
          deployment: if deploymentStaticLabels == defaultValue then defaultStaticLabels else deploymentStaticLabels,
        },

        hasNodeSelector():: nodeSelector != null,

        // Returns a promql selector suitable to `kube_*_label` metrics exported by
        // kube_state_metrics for
        getPromQLSelector(kubeMetricType)::
          local kubeSelectors = self[kubeMetricType];
          if kubeSelectors == null then
            null
          else
            kubeSelectorToPromSelector(kubeMetricType, kubeSelectors),

        // Returns a list of static labels to apply to metrics, as defined
        // on through static labels
        getStaticLabels(kubeMetricType)::
          self.staticLabels[kubeMetricType],
      },
  }
