local underTest = import './traffic-cessation-alerts.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local serviceDefinition = import 'servicemetrics/service_definition.libsonnet';

local serviceFixture = serviceDefinition.serviceDefinition({
  type: 'service_type',
  serviceLevelIndicators: {
    test_sli_no_cessation_alerts: {
      trafficCessationAlertConfig: false,
      userImpacting: false,
      requestRate: metricsCatalog.rateMetric(
        counter='gitaly_service_client_requests_total',
      ),
      significantLabels: [],
    },

    test_sli_cessation_alerts: {
      trafficCessationAlertConfig: true,
      userImpacting: false,
      requestRate: metricsCatalog.rateMetric(
        counter='gitaly_service_client_requests_total',
      ),
      significantLabels: [],
    },

    test_sli_partial_cessation_alerts: {
      trafficCessationAlertConfig: {
        test_aggregation_1: true,
        test_aggregation_2: false,
      },
      userImpacting: false,
      requestRate: metricsCatalog.rateMetric(
        counter='gitaly_service_client_requests_total',
      ),
      significantLabels: [],
    },

    test_sli_partial_cessation_alerts_with_selector: {
      trafficCessationAlertConfig: {
        test_aggregation_1: { selector1: 'value1' },
      },
      userImpacting: false,
      requestRate: metricsCatalog.rateMetric(
        counter='gitaly_service_client_requests_total',
      ),
      significantLabels: [],
    },

  },
});

local testAggregationBase = {
  name: 'Test',
  intermediateSource: false,
  selector: { monitor: 'global' },  // Not Thanos Ruler
  labels: ['environment', 'tier', 'type', 'stage'],
  burnRates: {
    '5m': {
      apdexRatio: 'apdex:ratio_5m',
      apdexWeight: 'apdex:weight:score_5m',
      opsRate: 'operation:rate_5m',
      errorRate: 'error:rate_5m',
      errorRatio: 'error:ratio_5m',
    },
    '30m': {
      apdexRatio: 'apdex:ratio_30m',
      apdexWeight: 'apdex:weight:score_30m',
      opsRate: 'operation:rate_30m',
      errorRate: 'error:rate_30m',
      errorRatio: 'error:ratio_30m',
    },
    '1h': {
      apdexRatio: 'apdex:ratio_1h',
      apdexWeight: 'apdex:weight:score_1h',
      opsRate: 'operation:rate_1h',
      errorRate: 'error:rate_1h',
      errorRatio: 'error:ratio_1h',
    },
    '6h': {
      apdexRatio: 'apdex:ratio_6h',
      apdexWeight: 'apdex:weight:score_6h',
      opsRate: 'operation:rate_6h',
      errorRate: 'error:rate_6h',
      errorRatio: 'error:ratio_6h',
    },
    '3d': {
      apdexRatio: 'apdex:ratio_3d',
      apdexWeight: 'apdex:weight:score_3d',
      opsRate: 'operation:rate_3d',
      errorRate: 'error:rate_3d',
      errorRatio: 'error:ratio_3d',
    },
  },
};

local testAggregationSet1 = aggregationSet.AggregationSet({
  id: 'test_aggregation_1',
} + testAggregationBase);

local testAggregationSet2 = aggregationSet.AggregationSet({
  id: 'test_aggregation_2',
} + testAggregationBase);

local testAggregationSet3 = aggregationSet.AggregationSet({
  id: 'test_aggregation_3',
} + testAggregationBase);

local alertDescriptorFixtureBase = {
  predicate: function(service) true,
  alertSuffix: '',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service (`{{ $labels.stage }}` stage)',
  alertExtraDetail: null,
  minimumSamplesForMonitoring: 10,
  alertForDuration: null,  // Use default for window...
  trafficCessationSelector: { stage: 'main' },  // Don't alert on cny stage traffic cessation for now
  minimumSamplesForTrafficCessation: 300,
};

local alertDescriptorFixture1 = alertDescriptorFixtureBase {
  aggregationSet: testAggregationSet1,
};

local alertDescriptorFixture2 = alertDescriptorFixtureBase {
  aggregationSet: testAggregationSet2,
};

local alertDescriptorFixture3 = alertDescriptorFixtureBase {
  aggregationSet: testAggregationSet3,
};


test.suite({
  // trafficCessationAlertConfig: false,
  testNoCessationAlerts: {
    actual: underTest(serviceFixture, serviceFixture.serviceLevelIndicators.test_sli_no_cessation_alerts, alertDescriptorFixture1),
    expect: [],
  },

  // trafficCessationAlertConfig: true,
  testCessationAlerts: {
    actual: underTest(serviceFixture, serviceFixture.serviceLevelIndicators.test_sli_cessation_alerts, alertDescriptorFixture1),
    expectThat: function(x) std.length(x) == 2,
  },

  // when [aggregation_set_id] is true, traffic cessation alerts are generated
  testCessationPartialAlertsTrue: {
    actual: underTest(serviceFixture, serviceFixture.serviceLevelIndicators.test_sli_partial_cessation_alerts, alertDescriptorFixture1),
    expectThat: function(x) std.length(x) == 2,
  },

  // when [aggregation_set_id] is false, no traffic cessation alerts
  testCessationPartialAlertsFalse: {
    actual: underTest(serviceFixture, serviceFixture.serviceLevelIndicators.test_sli_partial_cessation_alerts, alertDescriptorFixture2),
    expect: [],
  },

  // when [aggregation_set_id] is missing, traffic cessation alerts are generated
  testCessationPartialAlertsMissing: {
    actual: underTest(serviceFixture, serviceFixture.serviceLevelIndicators.test_sli_partial_cessation_alerts, alertDescriptorFixture3),
    expectThat: function(x) std.length(x) == 2,
  },

  // when [aggregation_set_id] contains a selector, it should be used in the expression
  testCessationPartialAlertsSelector: {
    actual: std.map(function(f) f.expr, underTest(serviceFixture, serviceFixture.serviceLevelIndicators.test_sli_partial_cessation_alerts_with_selector, alertDescriptorFixture1)),
    expect: [|||
      operation:rate_30m{component="test_sli_partial_cessation_alerts_with_selector",monitor="global",selector1="value1",stage="main",type="service_type"} == 0
      and
      operation:rate_30m{component="test_sli_partial_cessation_alerts_with_selector",monitor="global",selector1="value1",stage="main",type="service_type"} offset 1h >= 0.16666666666666666
    |||, |||
      operation:rate_5m{component="test_sli_partial_cessation_alerts_with_selector",monitor="global",selector1="value1",stage="main",type="service_type"} offset 1h
      unless
      operation:rate_5m{component="test_sli_partial_cessation_alerts_with_selector",monitor="global",selector1="value1",stage="main",type="service_type"}
    |||],
  },

})
