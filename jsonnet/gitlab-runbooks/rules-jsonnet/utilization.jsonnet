local utilizationMetrics = import 'servicemetrics/utilization-metrics.libsonnet';
local utilizationRules = import 'servicemetrics/utilization_rules.libsonnet';

utilizationRules.generateUtilizationRules(utilizationMetrics)
