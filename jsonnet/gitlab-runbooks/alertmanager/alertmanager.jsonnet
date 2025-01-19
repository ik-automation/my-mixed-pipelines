// Generate Alertmanager configurations
local secrets = std.extVar('secrets_file');
local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';

// Where the alertmanager templates are deployed.
local templateDir = '/etc/alertmanager/config';

// Special names of Slackbridge  webhook receivers.
// Note that these should match up with the names of the webhooks receivers kepts in
// the secrets in https://ops.gitlab.net/gitlab-com/runbooks/-/settings/ci_cd
local SLACKLINE_PRODUCTION_RECEIVER = 'slack_bridge-prod';
local SLACKLINE_STAGING_RECEIVER = 'slack_bridge-nonprod';

local slacklineReceiverMapping = {
  production: SLACKLINE_PRODUCTION_RECEIVER,
  staging: SLACKLINE_STAGING_RECEIVER,
};

// Map of webhook configurations for each slackline environment instance
// { staging: { .. }, production: { .. } }
local slacklineWebhookConfigurations = std.foldl(
  function(memo, environment)
    local slackWebhookNameForEnvironment = slacklineReceiverMapping[environment];
    local matchingWebhooks = std.filter(function(f) f.name == slackWebhookNameForEnvironment, secrets.webhookChannels);
    local first = if std.length(matchingWebhooks) == 1 then
      matchingWebhooks[0]
    else
      error 'Expected exactly one webhook named %s, but %d matched.' % [slackWebhookNameForEnvironment, std.length(matchingWebhooks)];

    memo { [environment]: first },
  std.objectFields(slacklineReceiverMapping),
  {}
);

//
// Receiver helpers and definitions.
local slackChannels = [
  // If slackchannels use Slackline (with `useSlackLine`), then the receiver will
  // not actually be a slack receiver, but will route to Slackline using a webhook
  // instead.
  { name: 'prod_alerts_slack_channel', channel: 'alerts' },
  { name: 'production_slack_channel', channel: 'production', sendResolved: false },
  { name: 'nonprod_alerts_slack_channel', channel: 'alerts-nonprod' },
  { name: 'feed_alerts_staging', channel: 'feed_alerts_staging', useSlackLine: slacklineWebhookConfigurations.staging },
];

local snitchReceiverChannelName(channel) =
  local env = channel.name;
  local cluster = if channel.cluster != '' then channel.cluster;
  local instance = if std.objectHas(channel, 'instance') then std.strReplace(channel.instance, '/', '_');
  local receiver_name = std.join('_', std.prune([env, cluster, instance]));
  'dead_mans_snitch_' + receiver_name;

local sendResolved(channel, default) =
  if std.objectHas(channel, 'sendResolved') then channel.sendResolved else default;

local webhookChannels =
  [
    { name: snitchReceiverChannelName(s), url: 'https://nosnch.in/' + s.apiKey, sendResolved: sendResolved(s, default=false) }
    for s in secrets.snitchChannels
  ] +
  [
    {
      name: w.name,
      url: w.url,
      sendResolved: sendResolved(w, default=true),
      httpConfig: {
        bearer_token: w.token,
      },
    }
    for w in secrets.webhookChannels
  ] +
  [
    {
      name: 'issue:' + s.name,
      url: 'https://' + s.name + '/alerts/notify.json',
      sendResolved: sendResolved(s, default=true),
      httpConfig: {
        bearer_token: s.token,
      },
    }
    for s in secrets.issueChannels
  ];

local PagerDutyReceiver(channel) = {
  name: channel.name,
  pagerduty_configs: [
    {
      service_key: channel.serviceKey,
      description: '{{ template "slack.title" . }}',
      client: 'GitLab Alertmanager',
      details: {
        firing: '{{ template "slack.text" . }}',
        alertname: '{{ .CommonLabels.alertname }}',
        component: '{{ .CommonLabels.component }}',
        feature_category: '{{ .CommonLabels.feature_category }}',
        product_stage: '{{ .CommonLabels.product_stage }}',
        product_stage_group: '{{ .CommonLabels.product_stage_group }}',
        stage: '{{ .CommonLabels.stage }}',
        tier: '{{ .CommonLabels.tier }}',
        type: '{{ .CommonLabels.type }}',
        user_impacting: '{{ .CommonLabels.user_impacting }}',
        env: '{{ .CommonLabels.env }}',
        fqdn: '{{ .CommonLabels.fqdn }}',
        node: '{{ .CommonLabels.node }}',
        pod: '{{ .CommonLabels.pod }}',
        region: '{{ .CommonLabels.region }}',
      },
      send_resolved: true,
    },
  ],
};

local webhookReceiverDefaults = {
  httpConfig: {},
};

local WebhookReceiver(channel) =
  local channelWithDefaults = webhookReceiverDefaults + channel;

  {
    name: channelWithDefaults.name,
    webhook_configs: [
      {
        url: channelWithDefaults.url,
        send_resolved: channelWithDefaults.sendResolved,
        http_config: channelWithDefaults.httpConfig,
      },
    ],
  };

local slackActionButton(text, url) =
  {
    type: 'button',
    text: text,
    url: std.stripChars(url, ' \n'),
  };

// Generates a "genuine" Slack receiver for cases where
// `useSlackLine` is false. Do not use directly, use SlackReceiver instead.
local RealSlackReceiver(channelWithDefaults) =
  {
    name: channelWithDefaults.name,
    slack_configs: [
      {
        channel: '#' + channelWithDefaults.channel,
        color: '{{ template "slack.color" . }}',
        icon_emoji: '{{ template "slack.icon" . }}',
        send_resolved: channelWithDefaults.sendResolved,
        text: '{{ template "slack.text" . }}',
        title: '{{ template "slack.title" . }}',
        title_link: '{{ template "slack.link" . }}',
        actions: [
          slackActionButton(  // runbook
            text='Runbook :green_book:',
            url=|||
              {{-  if ne (index .Alerts 0).Annotations.link "" -}}
                {{- (index .Alerts 0).Annotations.link -}}
              {{- else if ne (index .Alerts 0).Annotations.runbook "" -}}
                https://ops.gitlab.net/gitlab-com/runbooks/blob/master/{{ (index .Alerts 0).Annotations.runbook -}}
              {{- else -}}
                https://ops.gitlab.net/gitlab-com/runbooks/blob/master/docs/uncategorized/alerts-should-have-runbook-annotations.md
              {{- end -}}
            |||
          ),
          slackActionButton(  // Grafana link
            text='Dashboard :grafana:',
            url=|||
              {{-  if ne (index .Alerts 0).Annotations.grafana_dashboard_link "" -}}
                {{- (index .Alerts 0).Annotations.grafana_dashboard_link -}}
              {{- else if ne .CommonLabels.type "" -}}
                https://dashboards.gitlab.net/d/{{.CommonLabels.type}}-main?{{ if ne .CommonLabels.stage "" }}var-stage={{.CommonLabels.stage}}{{ end }}
              {{- else -}}
                https://dashboards.gitlab.net/
              {{- end -}}
            |||
          ),
          slackActionButton(  // Silence button
            text='Create Silence :shushing_face:',
            url=|||
              https://alerts.gitlab.net/#/silences/new?filter=%7B
              {{- range .CommonLabels.SortedPairs -}}
                  {{- if ne .Name "alertname" -}}
                      {{- .Name }}%3D%22{{- reReplaceAll " +" "%20" .Value -}}%22%2C%20
                  {{- end -}}
              {{- end -}}
              alertname%3D%7E%22
              {{- range $index, $alert := .Alerts -}}
                {{- if $index -}}%7C{{- end -}}
                {{- $alert.Labels.alertname -}}
              {{- end -}}
              %22%7D
            |||,
          ),
        ],
      },
    ],
  };

// Generates a "take" Slack receiver for cases where
// `useSlackLine` is configured. Do not use directly, use SlackReceiver instead.
local SlacklineSlackReceiver(channelWithDefaults, slackhookConfig) =
  local slackChannel = channelWithDefaults.channel;

  // Append ?channel=... to the slackline URL to use an alternative slack channel
  // More details in documentation at:
  // https://gitlab.com/gitlab-com/gl-infra/slackline/#publishing-messages-to-alternative-channels
  local url = '%s?channel=%s' % [slackhookConfig.url, slackChannel];

  WebhookReceiver({
    name: channelWithDefaults.name,
    url: url,
    sendResolved: true,
    httpConfig: {
      bearer_token: slackhookConfig.token,
    },
  });

local slackChannelDefaults = {
  // By default, resolved notifications are sent to the slack channel...
  sendResolved: true,

  // By default slack receivers will communicate directly with slack
  // this can be overriden to allow slack receivers to route via
  // slackline. The value should be 'staging' or 'production'
  useSlackLine: null,
};

// Generates either a "native" (real) Slack receiver, or, when
// useSlackLine is configured, will generate a webhook receiver which
// will route the notification to slackline.
local SlackReceiver(channel) =
  local channelWithDefaults = slackChannelDefaults + channel;

  if channelWithDefaults.useSlackLine == null then
    RealSlackReceiver(channelWithDefaults)
  else
    SlacklineSlackReceiver(channelWithDefaults, channelWithDefaults.useSlackLine);


//
// Route helpers and definitions.

// Returns a list of teams with valid `slack_alerts_channel` values
local teamsWithAlertingSlackChannels() =
  local allTeams = serviceCatalog.getTeams();
  std.filter(function(team) std.objectHas(team, 'slack_alerts_channel') && team.slack_alerts_channel != '', allTeams);

// Returns a list of stage group teams wiht slack channels for alerting
local teamsWithProductStageGroups() =
  std.filter(
    function(team) std.objectHas(team, 'product_stage_group'),
    teamsWithAlertingSlackChannels()
  );

local featureCategoriesWithTeams() =
  local teams = teamsWithProductStageGroups();
  std.flatMap(
    function(team)
      std.map(
        function(featureCategory)
          { teamName: team.name, featureCategory: featureCategory },
        stages.categoriesForStageGroup(team.product_stage_group)
      ),
    teams
  );

local defaultGroupBy = [
  'env',
  'tier',
  'type',
  'alertname',
  'stage',
  'component',
];

local groupByType = [
  'type',
  'env',
  'environment',
];

local Route(
  receiver,
  matchers=null,
  group_by=null,
  group_wait=null,
  group_interval=null,
  repeat_interval=null,
  continue=null,
  routes=null,
      ) =
  {
    receiver: receiver,
    [if matchers != null then 'matchers']: selectors.alertManagerMatchers(matchers),
    [if group_by != null then 'group_by']: group_by,
    [if group_wait != null then 'group_wait']: group_wait,
    [if group_interval != null then 'group_interval']: group_interval,
    [if repeat_interval != null then 'repeat_interval']: repeat_interval,
    [if routes != null then 'routes']: routes,
    [if continue != null then 'continue']: continue,
  };

local SnitchRoute(channel) =
  Route(
    receiver=snitchReceiverChannelName(channel),
    matchers={
      alertname: 'SnitchHeartBeat',
      cluster: channel.cluster,
      [if std.objectHas(channel, 'instance') then 'prometheus']: channel.instance,
      env: channel.name,
    },
    group_by=null,
    group_wait='1m',
    group_interval='5m',
    repeat_interval='5m',
    continue=false
  );

local receiverNameForTeamSlackChannel(teamName) =
  'team_' + std.strReplace(teamName, '-', '_') + '_alerts_channel';

local routingTree = Route(
  continue=null,
  group_by=defaultGroupBy,
  repeat_interval='8h',
  receiver='prod_alerts_slack_channel',
  routes=
  [
    /* SnitchRoutes do not continue */
    SnitchRoute(channel)
    for channel in secrets.snitchChannels
  ] +
  [
    /* issue alerts do continue */
    Route(
      receiver='issue:' + issueChannel.name,
      matchers={
        env: env,
        incident_project: issueChannel.name,
      },
      continue=true,
      group_wait='10m',
      group_interval='1h',
      repeat_interval='3d',
    )
    for issueChannel in secrets.issueChannels
    for env in ['gprd', 'ops']
  ] + [
    Route(
      receiver='prod_pagerduty',
      matchers={
        pager: 'pagerduty',
        env: { re: 'gprd|ops' },
      },
      group_by=groupByType,
      continue=true,
      /* must be less than the 6h auto-resolve in PagerDuty */
      repeat_interval='2h',
    ),
    /*
     * Send ops/gprd slackline alerts to production slackline
     * gstg slackline alerts go to staging slackline
     * other slackline alerts are passed up
     */
    Route(
      receiver=SLACKLINE_PRODUCTION_RECEIVER,
      matchers={
        rules_domain: 'general',
        env: 'gprd',
      },
      continue=true,
      // rules_domain='general' should be preaggregated so no need for additional groupBy keys
      group_by=['...']
    ),
    Route(
      receiver=SLACKLINE_PRODUCTION_RECEIVER,
      matchers={
        rules_domain: 'general',
        env: 'ops',
      },
      continue=true,
      // rules_domain='general' should be preaggregated so no need for additional groupBy keys
      group_by=['...']
    ),
    Route(
      receiver=SLACKLINE_STAGING_RECEIVER,
      matchers={
        rules_domain: 'general',
        /* Traffic cessation and traffic anomaly alerts should be disabled for
         * slackline-nonprod as they are very noisy */
        alert_class: { ne: 'traffic_cessation' },
        alertname: { nre: 'service_ops_out_of_bounds_upper_5m|service_ops_out_of_bounds_lower_5m' },
        env: { re: 'gstg(-ref)?' },
      },
      continue=true,
      // rules_domain='general' should be preaggregated so no need for additional groupBy keys
      group_by=['...']
    ),
  ] + [
    Route(
      receiver=receiverNameForTeamSlackChannel(featureCategoryTeam.teamName),
      continue=true,
      matchers={
        env: 'gprd',  // For now we only send production channel alerts to teams
        feature_category: featureCategoryTeam.featureCategory,
      },
    )
    for featureCategoryTeam in featureCategoriesWithTeams()
  ] + [
    Route(
      receiver=receiverNameForTeamSlackChannel(team.name),
      continue=true,
      matchers={
        env: 'gprd',  // For now we only send production channel alerts to teams
        product_stage_group: team.name,
      },
    )
    for team in teamsWithProductStageGroups()
  ] + [
    Route(
      receiver=receiverNameForTeamSlackChannel(team.name),
      continue=true,
      matchers={
        env: 'gprd',  // For now we only send production channel alerts to teams
        team: team.name,
      },
    )
    for team in teamsWithAlertingSlackChannels()
  ] +
  [
    // Route SLO alerts for staging to `feed_alerts_staging`
    Route(
      receiver='feed_alerts_staging',
      continue=true,
      matchers={
        env: { re: 'gstg(-ref)?' },
        slo_alert: 'yes',
        type: { re: 'api|web|git|registry|web-pages' },

        // Traffic volumes in staging are very low, and even lower in
        // the regional clusters. Since SLO alerting requires reasonable
        // traffic volumes, don't route regional alerts to the
        // slackline channel as they create a lot of noise.
        aggregation: { ne: 'regional_component' },
      },
    ),
  ] +
  [
    // Route Kubernetes alerts for staging to `feed_alerts_staging`
    Route(
      receiver='nonprod_alerts_slack_channel',
      continue=true,
      matchers={ env: { re: 'gstg(-ref)?' }, type: 'kube' },
    ),
  ]
  + [
    // Terminators go last
    Route(
      receiver='blackhole',
      matchers={ env: { re: 'db-(benchmarking|integration)|dr|gstg(-ref)?|pre|testbed' } },
      continue=false,
    ),
    // Pager alerts should appear in the production channel
    Route(
      receiver='production_slack_channel',
      matchers={ pager: 'pagerduty' },
      group_by=groupByType,
      continue=false,
    ),
    // All else to #alerts
    Route(
      receiver='prod_alerts_slack_channel',
      continue=false,
    ),
  ]
);


// Recursively walk a tree, adding all receiver names
local findAllReceiversInRoutingTree(tree, currentReceiverNamesSet) =
  local receiverNameSet = std.setUnion(currentReceiverNamesSet, [tree.receiver]);
  if std.objectHas(tree, 'routes') then
    std.foldl(function(memo, route) findAllReceiversInRoutingTree(route, memo), tree.routes, receiverNameSet)
  else
    receiverNameSet;

// Trim unused receivers to avoid warning messages from alertmanager
local pruneReceivers(receivers, routingTree) =
  local allReceivers = findAllReceiversInRoutingTree(routingTree, []);
  std.filter(function(r) std.setMember(r.name, allReceivers), receivers);

//
// Generate the list of routes and receivers.

local receivers =
  [PagerDutyReceiver(c) for c in secrets.pagerDutyChannels] +
  [SlackReceiver(c) for c in slackChannels] +

  // Generate receivers for each team that has a channel
  [SlackReceiver({
    name: receiverNameForTeamSlackChannel(team.name),
    channel: team.slack_alerts_channel,
  }) for team in teamsWithAlertingSlackChannels()] +
  [WebhookReceiver(c) for c in webhookChannels] +
  [
    // receiver that does nothing with the alert, blackholing it
    {
      name: 'blackhole',
    },
  ];

local inhibitRules() = std.flattenArrays(
  [
    sli.dependencies.generateInhibitionRules()
    for service in metricsCatalog.services
    for sli in service.listServiceLevelIndicators()
    if sli.hasDependencies()
  ]
);

// Generate the whole alertmanager config.
local alertmanager = {
  global: {
    slack_api_url: secrets.slackAPIURL,
  },
  receivers: pruneReceivers(receivers, routingTree),
  route: routingTree,
  templates: [
    templateDir + '/*.tmpl',
  ],
  inhibit_rules: inhibitRules(),
};

local k8sAlertmanagerSecret = {
  apiVersion: 'v1',
  kind: 'Secret',
  metadata: {
    name: 'alertmanager-config',
    namespace: 'monitoring',
  },
  data: {
    'alertmanager.yaml': std.base64(std.manifestYamlDoc(alertmanager)),
    'gitlab.tmpl': std.base64(importstr 'templates/gitlab.tmpl'),
    'slack.tmpl': std.base64(importstr 'templates/slack.tmpl'),
  },
};

{
  'alertmanager.yml': std.manifestYamlDoc(alertmanager, indent_array_in_object=true),
  'k8s_alertmanager_secret.yaml': std.manifestYamlDoc(k8sAlertmanagerSecret, indent_array_in_object=true),
}
