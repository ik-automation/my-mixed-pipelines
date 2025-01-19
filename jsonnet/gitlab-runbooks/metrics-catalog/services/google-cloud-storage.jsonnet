local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local maturityLevels = import 'service-maturity/levels.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'google-cloud-storage',
  tier: 'stor',
  monitoringThresholds: {
    apdexScore: 0.997,
    errorRatio: 0.9999,
  },
  regional: false,

  // Google Cloud Storage is a Cloud Service. No VMs, no Kubernetes
  provisioning: {
    vms: false,
    kubernetes: false,
  },

  serviceLevelIndicators: {
    registry_storage: {
      userImpacting: true,
      featureCategory: 'container_registry',
      description: |||
        Aggregation of all container registry GCS storage operations.
      |||,

      apdex: histogramApdex(
        histogram='registry_storage_action_seconds_bucket',
        selector={},
        satisfiedThreshold=1
      ),

      requestRate: rateMetric(
        counter='registry_storage_action_seconds_count',
      ),

      significantLabels: ['action', 'migration_path'],
    },

    workhorse_upload: {
      userImpacting: true,
      description: |||
        Monitors the performance of file uploads from Workhorse
        to GCS.
      |||,

      apdex: histogramApdex(
        histogram='gitlab_workhorse_object_storage_upload_time_bucket',
        selector={},
        satisfiedThreshold=25
      ),

      requestRate: rateMetric(
        counter='gitlab_workhorse_object_storage_upload_requests',
        selector={ le: '+Inf' },
      ),

      // Slightly misleading, but `gitlab_workhorse_object_storage_upload_requests`
      // only records error events.
      // see https://gitlab.com/gitlab-org/gitlab/blob/master/workhorse/internal/objectstore/prometheus.go
      errorRate: rateMetric(
        counter='gitlab_workhorse_object_storage_upload_requests',
        selector={},
      ),

      significantLabels: ['type'],
    },

    pages_range_requests: {
      userImpacting: true,
      description: |||
        Monitors the latency of time-to-first-byte of HTTP range requests issued from GitLab Pages to GCS.
      |||,

      apdex: histogramApdex(
        histogram='gitlab_pages_httprange_trace_duration_bucket',
        selector={ request_stage: 'httptrace.ClientTrace.GotFirstResponseByte' },
        satisfiedThreshold=0.5
      ),

      requestRate: rateMetric(
        counter='gitlab_pages_httprange_trace_duration_bucket',
        selector={ request_stage: 'httptrace.ClientTrace.GotFirstResponseByte', le: '+Inf' },
      ),

      significantLabels: [],
    },

    pages_request_duration: {
      userImpacting: true,
      description: |||
        Monitors the time it takes to get a response from an httprange. Resource hosted in object storage for a request made by the zip VFS.
      |||,

      apdex: histogramApdex(
        histogram='gitlab_pages_httprange_requests_duration_bucket',
        selector={ request_stage: 'httptrace.ClientTrace.GotFirstResponseByte' },
        satisfiedThreshold=0.5
      ),

      requestRate: rateMetric(
        counter='gitlab_pages_httprange_requests_duration_bucket',
        selector={ request_stage: 'httptrace.ClientTrace.GotFirstResponseByte', le: '+Inf' },
      ),

      significantLabels: [],
    },

    pages_total_requests: {
      userImpacting: true,
      description: |||
        The number of requests made by the zip VFS to a Resource with different status codes.
        Could be bigger than the number of requests served.
      |||,

      requestRate: rateMetric(
        counter='gitlab_pages_httprange_requests_total',
        selector={}
      ),
      significantLabels: ['type'],
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Structured logs available in Kibana': 'Access logs of GCS and not enabled due to volume.',
  }),
})
