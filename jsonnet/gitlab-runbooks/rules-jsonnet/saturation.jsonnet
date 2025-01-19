local saturationResources = import 'servicemetrics/saturation-resources.libsonnet';
local saturationRules = import 'servicemetrics/saturation_rules.libsonnet';

{
  'saturation.yml':
    std.manifestYamlDoc({
      groups: saturationRules.generateSaturationRulesGroup(
        includePrometheusEvaluated=true,
        includeDangerouslyThanosEvaluated=false,
        saturationResources=saturationResources
      ),
    }),
}
