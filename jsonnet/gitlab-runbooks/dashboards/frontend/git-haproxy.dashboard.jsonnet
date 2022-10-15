local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local text = grafana.text;
local template = grafana.template;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local platformLinks = import 'gitlab-dashboards//platform_links.libsonnet';

local httpsIngressTrafficFrontend = 'haproxy_frontend_bytes_in_total{frontend="https",env=~"${environment}"}';
local httpsEgressTrafficFrontend = 'haproxy_frontend_bytes_out_total{frontend="https",env=~"${environment}"}';
local httpsGitIngressTrafficBackend = 'haproxy_backend_bytes_in_total{backend=~".*https_git",env=~"${environment}"}';
local httpsGitEgressTrafficBackend = 'haproxy_backend_bytes_out_total{backend=~".*https_git",env=~"${environment}"}';
local httpsGitCiGatewayIngressTrafficFrontend = 'haproxy_frontend_bytes_in_total{frontend="https_git_ci_gateway",env=~"${environment}"}';
local httpsGitCiGatewayEgressTrafficFrontend = 'haproxy_frontend_bytes_out_total{frontend="https_git_ci_gateway",env=~"${environment}"}';

local rate = function(metric)
  'rate(%s[$__rate_interval])' % metric;

local dashboardRow = function(title, startRow, panels)
  layout.rowGrid(
    title,
    panels,
    startRow=startRow,
    rowHeight=6,
    collapse=false,
  );

local environmentTemplate = template.new(
  'environment',
  '$PROMETHEUS_DS',
  query=|||
    label_values(haproxy_frontend_bytes_in_total{frontend="https"}, env)
  |||,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
);

local trafficGraph = function(title, source)
  basic.timeseries(
    title=title,
    legendFormat='{{env}}',
    format='binBps',
    stack=false,
    interval='',
    intervalFactor=10,
    query=|||
      sum by(env) (
        %s
      )
    ||| % source,
  );

local trafficRatioGraph = function(title, part, total)
  basic.timeseries(
    title=title,
    legendFormat='{{env}}',
    format='percentunit',
    stack=false,
    interval='',
    intervalFactor=10,
    query=|||
      sum by(env) (
        %(part)s
      )
      /
      sum by(env) (
        %(total)s
      )
    ||| % {
      part: part,
      total: total,
    },
  );

local httpsTrafficGraph =
  trafficGraph(
    'total',
    '%(ingress)s + %(egress)s' % {
      ingress: rate(httpsIngressTrafficFrontend),
      egress: rate(httpsEgressTrafficFrontend),
    }
  );

local httpsIngressTrafficGraph =
  trafficGraph(
    'ingress',
    rate(httpsIngressTrafficFrontend),
  );

local httpsEgressTrafficGraph =
  trafficGraph(
    'egress',
    rate(httpsEgressTrafficFrontend),
  );

local httpsGitTrafficGraph =
  trafficGraph(
    'total',
    '%(ingress)s + %(egress)s' % {
      ingress: rate(httpsGitIngressTrafficBackend),
      egress: rate(httpsGitEgressTrafficBackend),
    }
  );

local httpsGitIngressTrafficGraph =
  trafficGraph(
    'ingress',
    rate(httpsGitIngressTrafficBackend),
  );

local httpsGitEgressTrafficGraph =
  trafficGraph(
    'egress',
    rate(httpsGitEgressTrafficBackend),
  );

local httpsGitCiGatewayTrafficGraph =
  trafficGraph(
    'total',
    '%(ingress)s + %(egress)s' % {
      ingress: rate(httpsGitCiGatewayIngressTrafficFrontend),
      egress: rate(httpsGitCiGatewayEgressTrafficFrontend),
    }
  );

local httpsGitCiGatewayIngressTrafficGraph =
  trafficGraph(
    'ingress',
    rate(httpsGitCiGatewayIngressTrafficFrontend),
  );

local httpsGitCiGatewayEgressTrafficGraph =
  trafficGraph(
    'egress',
    rate(httpsGitCiGatewayEgressTrafficFrontend),
  );

local httpsGitInHttpsTrafficGraph =
  trafficRatioGraph(
    'total',
    '%(httpsGitIngress)s + %(httpsGitEgress)s' % {
      httpsGitIngress: rate(httpsGitIngressTrafficBackend),
      httpsGitEgress: rate(httpsGitEgressTrafficBackend),
    },
    '%(httpsIngress)s + %(httpsEgress)s' % {
      httpsIngress: rate(httpsIngressTrafficFrontend),
      httpsEgress: rate(httpsEgressTrafficFrontend),
    },
  );

local httpsGitInHttpsIngressTrafficGraph =
  trafficRatioGraph(
    'ingress',
    rate(httpsGitIngressTrafficBackend),
    rate(httpsIngressTrafficFrontend),
  );

local httpsGitInHttpsEgressTrafficGraph =
  trafficRatioGraph(
    'egress',
    rate(httpsGitEgressTrafficBackend),
    rate(httpsEgressTrafficFrontend),
  );

local httpsGitCiGatewayInHttpsGitTrafficGraph =
  trafficRatioGraph(
    'total',
    '%(httpsGitCiGatewayIngress)s + %(httpsGitCiGatewayEgress)s' % {
      httpsGitCiGatewayIngress: rate(httpsGitCiGatewayIngressTrafficFrontend),
      httpsGitCiGatewayEgress: rate(httpsGitCiGatewayEgressTrafficFrontend),
    },
    '%(httpsGitIngress)s + %(httpsGitEgress)s' % {
      httpsGitIngress: rate(httpsGitIngressTrafficBackend),
      httpsGitEgress: rate(httpsGitEgressTrafficBackend),
    },
  );

local httpsGitCiGatewayInHttpsGitIngressTrafficGraph =
  trafficRatioGraph(
    'ingress',
    rate(httpsGitCiGatewayIngressTrafficFrontend),
    rate(httpsGitIngressTrafficBackend),
  );

local httpsGitCiGatewayInHttpsGitEgressTrafficGraph =
  trafficRatioGraph(
    'egress',
    rate(httpsGitCiGatewayEgressTrafficFrontend),
    rate(httpsGitEgressTrafficBackend),
  );

basic.dashboard(
  'ci-gateway Git utilisation based on HaProxy',
  tags=[
    'managed',
    'type:frontend',
  ],
  time_from='now-24h/m',
  time_to='now/m',
  graphTooltip='shared_crosshair',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
)
.addTemplate(environmentTemplate)
.addPanels(
  dashboardRow(
    'HTTPs Git traffic as a percentage of main HTTPs frontend traffic',
    10,
    [
      httpsGitInHttpsTrafficGraph,
      httpsGitInHttpsIngressTrafficGraph,
      httpsGitInHttpsEgressTrafficGraph,
    ],
  )
)
.addPanels(
  dashboardRow(
    'HTTPs CI Gateway traffic as a percentage of all Git HTTPs backend traffic',
    20,
    [
      httpsGitCiGatewayInHttpsGitTrafficGraph,
      httpsGitCiGatewayInHttpsGitIngressTrafficGraph,
      httpsGitCiGatewayInHttpsGitEgressTrafficGraph,
    ],
  )
)
.addPanels(
  dashboardRow(
    'HTTPs traffic - based on the main HTTPs HaProxy frontend',
    30,
    [
      httpsTrafficGraph,
      httpsIngressTrafficGraph,
      httpsEgressTrafficGraph,
    ],
  )
)
.addPanels(
  dashboardRow(
    'HTTPs Git traffic - based on the HaProxy backend',
    40,
    [
      httpsGitTrafficGraph,
      httpsGitIngressTrafficGraph,
      httpsGitEgressTrafficGraph,
    ],
  )
)
.addPanels(
  dashboardRow(
    'HTTPs CI Gateway traffic - based on the dedicated HaProxy frontend',
    50,
    [
      httpsGitCiGatewayTrafficGraph,
      httpsGitCiGatewayIngressTrafficGraph,
      httpsGitCiGatewayEgressTrafficGraph,
    ],
  )
)
.trailer() + {
  links+: [
    platformLinks.dynamicLinks('frontend Detail', 'type:frontend'),
  ],
}
