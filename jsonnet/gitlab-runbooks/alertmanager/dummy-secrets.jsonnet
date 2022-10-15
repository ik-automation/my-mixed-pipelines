// Dummy secrets for CI testing.
{
  // GitLab issue webhook receivers.
  issueChannels: [
    { name: 'gitlab.com/gitlab-com/gl-infra/infrastructure', token: 'secret' },
    { name: 'gitlab.com/gitlab-com/gl-infra/production', token: 'secret' },
    { name: 'gitlab.com/gitlab-com/gl-infra/capacity-planning', token: 'secret', sendResolved: false },
  ],
  // PagerDuty services.
  pagerDutyChannels: [
    { name: 'non_prod_pagerduty', serviceKey: 'secret' },
    { name: 'prod_pagerduty', serviceKey: 'secret' },
    { name: 'slo_dr', serviceKey: 'secret' },
    { name: 'slo_gprd_cny', serviceKey: 'secret' },
    { name: 'slo_gprd_main', serviceKey: 'secret' },
    { name: 'slo_non_prod', serviceKey: 'secret' },
  ],
  // GitLab Slack.
  slackAPIURL: 'https://example.com/secret',
  // https://deadmanssnitch.com/
  snitchChannels: [
    { name: 'alertmanager-notifications', apiKey: 'secret', cluster: '' },
    { name: 'ops', apiKey: 'secret', cluster: '' },
    { name: 'ops', apiKey: 'secret', cluster: 'ops-gitlab-gke' },
    { name: 'gprd', apiKey: 'secret', cluster: '' },
    { name: 'gprd', apiKey: 'secret', cluster: 'gprd-gitlab-gke', instance: 'monitoring/gitlab-monitoring-promethe-prometheus' },
    { name: 'gprd', apiKey: 'secret', cluster: 'gprd-gitlab-gke', instance: 'monitoring/prometheus-gitlab-app-1-pr-prometheus' },
    { name: 'gstg', apiKey: 'secret', cluster: '' },
    { name: 'gstg-ref', apiKey: 'secret', cluster: 'staging-ref-10k-hybrid' },
    { name: 'pre', apiKey: 'secret', cluster: '' },
    { name: 'testbed', apiKey: 'secret', cluster: '' },
    { name: 'thanos-rule', apiKey: 'secret', cluster: '' },
    { name: 'other-rule', apiKey: 'secret', cluster: '', sendResolved: true },
  ],
  // Generic webhook configs.
  webhookChannels: [
    { name: 'slack_bridge-nonprod', url: 'http://staging.cloudfunctions.net/alertManagerBridge', token: 'staging_secret' },
    { name: 'slack_bridge-prod', url: 'http://production.cloudfunctions.net/alertManagerBridge', token: 'production_secret', sendResolved: false },
  ],
}
