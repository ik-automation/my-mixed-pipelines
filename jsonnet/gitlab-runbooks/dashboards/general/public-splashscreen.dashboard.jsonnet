local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local keyMetrics = import 'gitlab-dashboards/key_metrics.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local text = grafana.text;

local selector = { stage: 'main', env: '$environment', environment: '$environment' };

basic.dashboard(
  'GitLab Dashboards',
  tags=['general']
)
.addPanel(
  text.new(
    mode='markdown',
    content=|||
      # GitLab Public Dashboards

      Our internal dashboards are no longer available publicly due to stability and confidentiality concerns (see https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/14432).

      Key metrics will now be published on our status page instead: https://status.gitlab.com/ (see https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/698).

      Our dashboards are managed using Grafonnet, and the source is [publicly available on GitLab.com](https://gitlab.com/gitlab-com/runbooks/tree/master/dashboards).
    |||
  ),
  gridPos={
    x: 0,
    y: 0,
    w: 12,
    h: 6,
  }
)
.addPanel(
  text.new(
    mode='markdown',
    content=|||
      # Useful Links

      * **[Platform Triage Dashboard](/d/general-triage/general-platform-triage?orgId=1)** technical overview for all services.
      * **[Capacity Planning Dashboard](/d/general-capacity-planning/general-capacity-planning?orgId=1)** resources currently saturated, or at risk of becoming saturated.
      * **[Service SLA Dashboard](/d/general-slas/general-slas?orgId=1)** service SLA tracking.
      * **[Source repository for these dashboards](https://gitlab.com/gitlab-com/runbooks/tree/master/dashboards)** - interested in how we use [grafonnet-lib](https://github.com/grafana/grafonnet-lib)
        to build our dashboards?

    |||
  ),
  gridPos={
    x: 12,
    y: 0,
    w: 12,
    h: 6,
  }
)
.addPanel(
  row.new(title='FRONTEND SERVICES'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanel(
  text.new(
    title='Help',
    mode='markdown',
    content=|||
      This graphs show the frontend services that GitLab customer traffic will be initially handled by. Any issues in this
      fleet are more likely to be user-impacting.
    |||
  ),
  gridPos={
    x: 0,
    y: 1001,
    w: 24,
    h: 2,
  }
)
.addPanels(keyMetrics.headlineMetricsRow('web', startRow=1100, rowTitle='Web traffic: gitlab.com', selectorHash=selector, stableIdPrefix='web', showDashboardListPanel=true))
.addPanels(keyMetrics.headlineMetricsRow('api', startRow=1200, rowTitle='API: gitlab.com/api traffic', selectorHash=selector, stableIdPrefix='api', showDashboardListPanel=true))
.addPanels(keyMetrics.headlineMetricsRow('git', startRow=1300, rowTitle='Git: git ssh and https traffic', selectorHash=selector, stableIdPrefix='git', showDashboardListPanel=true))
.addPanels(keyMetrics.headlineMetricsRow('ci-runners', startRow=1400, rowTitle='CI Runners', selectorHash=selector, stableIdPrefix='ci-runners', showDashboardListPanel=true))
.addPanels(keyMetrics.headlineMetricsRow('registry', startRow=1500, rowTitle='Container Registry', selectorHash=selector, stableIdPrefix='registry', showDashboardListPanel=true))
.trailer()
