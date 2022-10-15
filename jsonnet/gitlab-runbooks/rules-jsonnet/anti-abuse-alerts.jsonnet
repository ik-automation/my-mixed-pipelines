local alerts = import 'alerts/alerts.libsonnet';

local rules = {
  groups: [
    {
      name: 'anti_abuse_alerts',
      rules: [
        alerts.processAlertRule({
          alert: 'RunnerJobDurationSpikeDetected',
          expr: |||
            sum by (environment, tier, type)  (
              rate(
                gitlab_runner_job_duration_seconds_sum{shard="shared"}[5m]
               )
             )
             > 15000
          |||,
          'for': '3m',
          labels: {
            team: 'anti_abuse',
            severity: 's4',
            alert_type: 'symptom',
          },
          annotations: {
            title: 'Suspicious spike detected in the runner job durations.',
            description: |||
              The sum total time of CI jobs exceeded a threshold of 15,000 seconds per second for a 3 minute period; this can indicate crypto mining or other pipeline abuse.
            |||,
            grafana_dashboard_id: 'ci-runners-business-stats',
            grafana_min_zoom_hours: '4',
            grafana_variables: 'environment',
          },
        }),
      ],
    },
  ],
};

{
  'anti-abuse-alerts.yml': std.manifestYamlDoc(rules),
}
