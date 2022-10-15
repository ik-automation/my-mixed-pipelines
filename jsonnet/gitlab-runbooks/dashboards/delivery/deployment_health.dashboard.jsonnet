local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local prometheus = grafana.prometheus;
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local annotation = grafana.annotation;
local graphPanel = grafana.graphPanel;
local row = grafana.row;
local statPanel = grafana.statPanel;
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local textPanel = grafana.text;

basic.dashboard(
  'Deployment Health',
  tags=['release'],
  editable=true,
  includeStandardEnvironmentAnnotations=true,
  includeEnvironmentTemplate=true,
)
.addTemplate(templates.stage)

.addPanel(
  row.new(title='Overview'),
  gridPos={ x: 0, y: 0, w: 24, h: 8 },
)
.addPanel(
  graphPanel.new(
    'Deploy Health',
    description='Showcases whether or not an environment and its stage is healthy',
    decimals=0,
    fill=0,
    format='none',
    legend_show=false,
    min=0,
  )
  .addTarget(
    prometheus.target(
      'gitlab_deployment_health:stage{env="$environment", stage="$stage"}',
      legendFormat='Health'
    ),
  ), gridPos={ x: 0, y: 0, w: 16, h: 12 }
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      This panel shows the Deployment Health which is taking into account all
      services for the provided $environment and $stage selected

      Values provided are effectively a boolean.  Where `1` is true, or in the
      case of metrics, a *healthy* state.  Where `0` is false, or in this case,
      *unhealthy*.

      View the **Service Deployment Health** for a breakdown of each
      contributing service that is rolled into this metric.
    |||
  ), gridPos={ x: 16, y: 0, w: 8, h: 12 }
)

.addPanel(
  row.new(title='Service Breakdown'),
  gridPos={ x: 0, y: 1, w: 24, h: 8 },
)
.addPanel(
  graphPanel.new(
    'Service Deployment Health',
    description='Showcases whether or not the environments stage is healthy with a breakdown by the individual services that contribute to the metric',
    decimals=0,
    fill=10,
    legend_alignAsTable=true,
    legend_current=true,
    legend_min=true,
    legend_rightSide=true,
    legend_values=true,
    min=0,
    stack=true
  )
  .addTarget(
    prometheus.target(
      'gitlab_deployment_health:service{env="$environment", stage="$stage", type!="registry"}',
      legendFormat='{{type}}',
    ),
  ), gridPos={ x: 0, y: 1, w: 16, h: 12 }
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      This panel shows the Deployment Health which is showcasing each of the
      services that are a blocker for deployments.

      Values provided are effectively a boolean.  Where `1` is true, or in the
      case of metrics, a *healthy* state.  Where `0` is false, or in this case,
      *unhealthy*.

      We are using a stack chart to show case each metric individually in an
      easier fashion.

      View the **Component Breakdown** for a breakdown of each contributing
      metric that is rolled into this metrics.
    |||
  ), gridPos={ x: 16, y: 1, w: 8, h: 12 }
)

.addPanel(
  row.new(title='Component Breakdown'),
  gridPos={ x: 0, y: 2, w: 24, h: 8 },
)
.addTemplate(templates.type)
.addPanel(
  graphPanel.new(
    'Component Deployment Health',
    description='Showcases whether or not the environments stage is healthy with a breakdown by the individual services that contribute to the metric',
    decimals=0,
    fill=10,
    legend_alignAsTable=true,
    legend_current=true,
    legend_min=true,
    legend_rightSide=true,
    legend_values=true,
    min=0,
    stack=true
  )
  .addTarget(
    prometheus.target(
      'gitlab_deployment_health:service:apdex{env="$environment", stage="$stage", type="$type"}',
      legendFormat='Apdex',
    ),
  )
  .addTarget(
    prometheus.target(
      'gitlab_deployment_health:service:errors{env="$environment", stage="$stage", type="$type"}',
      legendFormat='Errors',
    ),
  ), gridPos={ x: 0, y: 2, w: 16, h: 12 }
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      This panel shows the Deployment Health which is showcasing each of the
      contributing factors, Apdex, and Error SLI's and whether or not they
      are within the service boundaries.

      Values provided are effectively a boolean.  Where `1` is true, or in the
      case of metrics, a *healthy* state.  Where `0` is false, or in this case,
      *unhealthy*.

      We're using a stack chart to show case each metric individually in an
      easier fashion.
    |||
  ), gridPos={ x: 16, y: 2, w: 8, h: 12 }
)

.addPanel(
  row.new(title='Component Deployment Health Breakdown'),
  gridPos={ x: 0, y: 3, w: 24, h: 8 },
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      Utilize the below links to browse to the various dashboards that
      showcases the burnrates for the various windows of time that contribute
      towards to deployment health metric for the selected component, stage,
      and environment.
        - [Error SLO Analysis](https://dashboards.gitlab.net/d/alerts-service_slo_error/alerts-global-service-aggregated-metrics-error-slo-analysis?orgId=1&var-PROMETHEUS_DS=Global&var-environment=%(environment)s&var-type=%(type)s&var-stage=%(stage)s&var-proposed_slo=0.999)
        - [Apdex SLO Analysis](https://dashboards.gitlab.net/d/alerts-service_slo_apdex/alerts-global-service-aggregated-metrics-apdex-slo-analysis?orgId=1&var-PROMETHEUS_DS=Global&var-environment=%(environment)s&var-type=%(type)s&var-stage=%(stage)s&var-proposed_slo=0.997)
    ||| % { environment: '$environment', type: '$type', stage: '$stage' }
  ), gridPos={ x: 0, y: 3, w: 8, h: 8 }
)
.trailer()
