local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local maturityLevels = import 'service-maturity/levels.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'jaeger',
  tier: 'inf',
  monitoringThresholds: {
    // apdexScore: 0.999,
    errorRatio: 0.999,
  },
  serviceLevelIndicators: {
    jaeger_agent: {
      userImpacting: false,
      requestRate: rateMetric(
        counter='jaeger_agent_reporter_spans_submitted_total',
        selector='type="jaeger"',
      ),

      errorRate: rateMetric(
        counter='jaeger_agent_reporter_spans_failures_total',
        selector='type="jaeger"',
      ),

      significantLabels: ['fqdn', 'instance'],
    },

    jaeger_collector: {
      userImpacting: false,
      apdex: histogramApdex(
        histogram='jaeger_collector_save_latency_bucket',
        selector='type="jaeger"',
        satisfiedThreshold=10,
      ),

      requestRate: rateMetric(
        counter='jaeger_collector_spans_received_total',
        selector='type="jaeger"',
      ),

      errorRate: rateMetric(
        counter='jaeger_collector_spans_dropped_total',
        selector='type="jaeger"'
      ),

      significantLabels: ['fqdn', 'pod'],
    },

    jaeger_query: {
      userImpacting: false,
      apdex: histogramApdex(
        histogram='jaeger_query_latency_bucket',
        selector='type="jaeger"',
        satisfiedThreshold=10,
      ),

      requestRate: rateMetric(
        counter='jaeger_query_requests_total',
        selector='type="jaeger"',
      ),

      errorRate: rateMetric(
        counter='jaeger_query_requests_total',
        selector='result="err"'
      ),

      significantLabels: ['fqdn', 'pod'],
    },
  },
  skippedMaturityCriteria: maturityLevels.skip({
    'Service exists in the dependency graph': 'Jaeger is an independent internal observability tool',
    'Structured logs available in Kibana': 'Jaeger service is not deployed in production',
  }),
})
