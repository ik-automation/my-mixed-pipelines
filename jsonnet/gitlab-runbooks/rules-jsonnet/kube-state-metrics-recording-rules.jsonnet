local groups = import 'kube-state-metrics/recording-rules.libsonnet';

{
  'kube-state-metrics-recording-rules.yml': std.manifestYamlDoc({
    groups: groups,
  }),
}
