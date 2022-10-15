local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local text = grafana.text;
local template = grafana.template;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local platformLinks = import 'gitlab-dashboards//platform_links.libsonnet';

local haproxyRejections = 'haproxy_backend_sessions_total{env=~"${environment}", backend=~"deny_https?"}';

local rate = function(metric)
  'rate(%s[$__rate_interval])' % metric;

local dashboardRow = function(title, startRow, panels)
  layout.rowGrid(
    title,
    panels,
    startRow=startRow,
    rowHeight=10,
    collapse=false,
  );

local trafficGraph = function(title, source)
  basic.timeseries(
    title=title,
    legendFormat='{{env}}',
    format='short',
    stack=false,
    interval='',
    intervalFactor=2,
    query=|||
      sum by(backend) (
        %s
      )
    ||| % source,
  );

basic.dashboard(
  'HAProxy rejections due to rate limiting and blocks',
  tags=[
    'type:web-pages',
  ],
  time_from='now-6h/m',
  time_to='now/m',
  graphTooltip='shared_crosshair',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=true,
)
.addPanels(
  layout.grid([
    grafana.text.new(
      title='Explainer',
      mode='markdown',
      content=|||
        ### What is this?

        This dashboard shows the number of HAProxy rejections due to blocks and rate limits.

        Rejections occur for any of the following reasons:

        - Requests exceed our per domain rate limits at HAProxy, see [documentation for rate limits](https://gitlab.com/gitlab-com/runbooks/-/tree/master/docs/rate-limiting).
        - Domain is on the [domain block list](https://gitlab.com/gitlab-com/security-tools/front-end-security/-/blob/master/deny-403-pages-domains.lst)
        - IP is on the [IP block list](https://gitlab.com/gitlab-com/security-tools/front-end-security/-/blob/master/deny-403-ips.lst)

        #### Rejections

        - HTTPs (`deny_https`) will manifest to the user as an SSL error since we terminate SSL at the Pages application.
        - HTTP (`deny_http`) will manifest to the user as a normal`429` status code, this will show up in our status code counters

        **Note**: HTTPs rejections do not show up in any status code counters or as errors for the Load Balancer.
      |||
    ),
  ], cols=1, rowHeight=10, startRow=1)
)
.addPanels(
  dashboardRow(
    'Rejections due to rate limiting or blocks',
    10,
    [
      trafficGraph(
        'HAProxy rejections (rejections/second)',
        rate(haproxyRejections),
      ),
    ],
  )
)
.trailer() + {
  links+: [
    platformLinks.dynamicLinks('web-pages Detail', 'type:web-pages'),
  ],
}
