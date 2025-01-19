local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local rateMetric = metricsCatalog.rateMetric;
local googleLoadBalancerComponents = import './lib/google_load_balancer_components.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';

// See https://www.vaultproject.io/docs/internals/telemetry for more details about Vault metrics

metricsCatalog.serviceDefinition({
  type: 'vault',
  tier: 'inf',

  tags: ['golang'],

  serviceIsStageless: true,

  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },

  provisioning: {
    kubernetes: true,
    vms: false,
  },

  kubeConfig: {
    local kubeSelector = { namespace: 'vault' },

    labelSelectors: kubeLabelSelectors(
      nodeSelector={ type: 'vault' }
    ),
  },

  kubeResources: {
    vault: {
      kind: 'StatefulSet',
      containers: [
        'vault',
      ],
    },
  },

  serviceLevelIndicators: {
    // Google Load Balancer for https://vault.gitlab.net
    vault_google_lb: googleLoadBalancerComponents.googleLoadBalancer(
      userImpacting=false,
      // LB automatically created by the k8s ingress
      loadBalancerName='k8s2-um-4zodnh0s-vault-vault-g7tjn6qu',
      projectId='gitlab-ops',
      trafficCessationAlertConfig=false
    ),

    vault: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        Hashicorp Vault is a secret management service that provides secrets for Kubernetes and provisioning pipelines.
        This SLI monitors the Vault HTTP interface. 5xx responses are considered failures.
      |||,

      local vaultSelector = {
        job: 'vault-active',
      },

      requestRate: rateMetric(
        counter='vault_core_handle_request_count',
        selector=vaultSelector,
      ),

      significantLabels: ['pod'],
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Structured logs available in Kibana': "Vault is a pending project at the moment. There is no traffic at the moment. We'll add logs and metrics in https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/739",
    'Service exists in the dependency graph': 'Vault is a pending project at the moment. There is no traffic at the moment. The progress can be tracked at https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/739',
    'Developer guides exist in developer documentation': 'Vault is an infrastructure component, developers do not interact with it',
  }),
})
