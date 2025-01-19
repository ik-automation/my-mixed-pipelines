local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local timepickerlib = import 'github.com/grafana/grafonnet-lib/grafonnet/timepicker.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local row = grafana.row;
local templates = import 'grafana/templates.libsonnet';
local graphPanel = grafana.graphPanel;
local generalGraphPanel(
  title,
  fill=1,
  format=null,
  formatY1=null,
  formatY2=null,
  decimals=3,
  description=null,
  linewidth=2,
  sort=0,
      ) = graphPanel.new(
  title,
  linewidth=linewidth,
  fill=fill,
  format=format,
  formatY1=formatY1,
  formatY2=formatY2,
  datasource='$PROMETHEUS_DS',
  description=description,
  decimals=decimals,
  sort=sort,
  legend_show=false,
  legend_values=false,
  legend_min=false,
  legend_max=true,
  legend_current=true,
  legend_total=false,
  legend_avg=true,
  legend_alignAsTable=true,
  legend_hideEmpty=false,
  legend_rightSide=true,
);

local networkPanel(
  title,
  filter,
  tx_metric='node_network_transmit_bytes_total',
  rcv_metric='node_network_receive_bytes_total'
      ) =

  generalGraphPanel(title)
  .addTarget(
    promQuery.target('sum(increase(%(metric)s{device!="lo", %(filter)s, env="$environment"}[1d]))' % { metric: tx_metric, filter: filter }, legendFormat='egress')
  )
  .addTarget(
    promQuery.target('sum(increase(%(metric)s{device!="lo", %(filter)s, env="$environment"}[1d])) * -1' % { metric: rcv_metric, filter: filter }, legendFormat='ingress')
  )
  .resetYaxes()
  .addYaxis(
    format='bytes',
    label='bytes',
  )
  .addYaxis(
    format='byte',
    show=false,
  );

local networkPanelK8s(
  title,
  filter,
  tx_metric='container_network_transmit_bytes_total:labeled',
  rcv_metric='container_network_receive_bytes_total:labeled'
      ) =

  generalGraphPanel(title)
  .addTarget(
    promQuery.target('sum(increase(%(metric)s{device!="lo", %(filter)s, env="$environment"}[1d]))' % { metric: tx_metric, filter: filter }, legendFormat='egress')
  )
  .addTarget(
    promQuery.target('sum(increase(%(metric)s{device!="lo", %(filter)s, env="$environment"}[1d])) * -1' % { metric: rcv_metric, filter: filter }, legendFormat='ingress')
  )
  .resetYaxes()
  .addYaxis(
    format='bytes',
    label='bytes',
  )
  .addYaxis(
    format='byte',
    show=false,
  );

local osPanel(title) =
  generalGraphPanel(title)
  .addTarget(
    promQuery.target('sum by (bucket_name) (sum_over_time(stackdriver_gcs_bucket_storage_googleapis_com_network_sent_bytes_count{env="$environment"}[1h]))', legendFormat='egress {{ bucket_name }}', interval='1h')
  )
  .addTarget(
    promQuery.target('sum by (bucket_name) (sum_over_time(stackdriver_gcs_bucket_storage_googleapis_com_network_received_bytes_count{env="$environment"}[1h])) * -1', legendFormat='ingress {{ bucket_name }}', interval='1h')
  )
  .resetYaxes()
  .addYaxis(
    format='bytes',
    label='bytes',
  )
  .addYaxis(
    format='byte',
    show=false,
  );

basic.dashboard(
  'Network Ingress/Egress Overview',
  tags=['general'],
  editable=true,
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  time_from='now-14d',
  time_to='now'
)

.addTemplate(templates.environment)

// ----------------------------------------------------------------------------
// Overview
// ----------------------------------------------------------------------------

.addPanels(
  layout.grid([
    grafana.text.new(
      title='Explainer',
      mode='markdown',
      content=|||
        ### What is this?

        Amount of ingress / egress traffic **per day**, for nodes (Virtual Machines) and HAProxy Backends

        * HAProxy Nodes: Ingress/Egress bytes from the VMs
          * registry: registry.gitlab.com traffic
          * fe: gitlab.com traffic (via cloudflare)
          * pages: *.gitlab.io and pages custom domains
        * Fleet
          * git (K8s): git-https, git-ssh, websockets
          * api (K8s): gitlab.com public api, gitlab.com/v4/api/*
          * web (K8s): gitlab.com web traffic, anything that is not gitlab.com/v4/api/*
          * web-pages (K8s): *.gitlab.io pages traffic
        * Storage
          * file: All projects/wikis from local disk, this is where gitaly runs
          * pages: NFS server for *.gitlab.io gitlab pages
          * share: Shared cache for job traces and artifacts
          * patroni: All postgres database servers
          * redis: All redis clusters
          * object storagE: All object storage buckets
      |||
    ),
    grafana.text.new(
      title='HAProxy Backends',
      mode='markdown',
      content=|||
        ### HAProxy Backend Network Reporting

        **HAProxy backend reporting looks different than egress/ingress node metrics.**

        This is because we are using HAProxy application metrics that allow us to see data
        flowing in and out of individual backends.

        * Web / API / HTTPs Git / Git SSH / Websockets - This traffic is served by the HAProxy Fe nodes
        * Registry - This traffic is served by the HAProxy Registry nodes
        * Pages - This traffic is served by the HAProxy Pages nodes

        Note that some of the graphs are more lopsided than the node graphs, see the FAQ for an explanation.
      |||
    ),

    grafana.text.new(
      title='FAQ',
      mode='markdown',
      content=|||
        ## FAQ

        * Why is the fleet node bandwidth so symetrical? Shouldn't we be sending more than we receive?
          * Most of our traffic is proxied to storage services, or to object storage.
        * Do clients download direct from object storage?
          * It depends.
            * registry: all image pulls are direct from object storage
            * uploads/lfs/merge-request-diffs: currently set to proxy but we might change that
              https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/10117
        * Why for HAProxy Registry backend traffic, is there so much more ingress than egress?
          * Registry downloads are direct from Object Storage
        * Why for HAProxy HTTPs and SSH Git traffic is egress so much more than ingress?
          * We are sending more Git data to clients than we are receiving
        * What about canary traffic?
          * Canary traffic is included in production traffic
        * What is websockets used for?
          * Websockets is only used right now for the interractive terminal, and actioncable
      |||
    ),
  ], cols=3, rowHeight=13, startRow=1)
)

// ----------------------------------------------------------------------------
// Network Panels
// ----------------------------------------------------------------------------
.addPanel(
  row.new(title='HAProxy data transfer by Backend'),
  gridPos={ x: 0, y: 2, w: 24, h: 12 },
)
.addPanels(
  layout.grid([
    networkPanel(
      'HTTPs Git Data Transfer / 24h',
      'backend=~".*https_git$"',
      'haproxy_backend_bytes_out_total',
      'haproxy_backend_bytes_in_total',
    ),
    networkPanel(
      'Registry Data Transfer / 24h',
      'backend=~".*registry$"',
      'haproxy_backend_bytes_out_total',
      'haproxy_backend_bytes_in_total',
    ),
    networkPanel(
      'API Data Transfer / 24h',
      'backend=~".*api$"',
      'haproxy_backend_bytes_out_total',
      'haproxy_backend_bytes_in_total',
    ),
    networkPanel(
      'Web Data Transfer / 24h',
      'backend=~".*web$"',
      'haproxy_backend_bytes_out_total',
      'haproxy_backend_bytes_in_total',
    ),
  ], cols=4, rowHeight=7, startRow=2)
)
.addPanels(
  layout.grid([
    networkPanel(
      'Pages Data Transfer / 24h',
      'backend=~".*pages_https?$"',
      'haproxy_backend_bytes_out_total',
      'haproxy_backend_bytes_in_total',
    ),
    networkPanel(
      'WebSockets Data Transfer / 24h',
      'backend=~".*websockets$"',
      'haproxy_backend_bytes_out_total',
      'haproxy_backend_bytes_in_total',
    ),
    networkPanel(
      'SSH Data Transfer / 24h',
      'backend=~".*ssh$"',
      'haproxy_backend_bytes_out_total',
      'haproxy_backend_bytes_in_total',
    ),

  ], cols=3, rowHeight=7, startRow=3)
)

.addPanel(
  row.new(title='HAProxy Nodes'),
  gridPos={ x: 0, y: 4, w: 24, h: 12 },
)
.addPanels(
  layout.grid([
    networkPanel('Fe (HAProxy) Registry Data Transfer / 24h', 'fqdn=~"^fe-registry-[0-9].*"'),
    networkPanel('Fe (HAProxy) Data Transfer / 24h', 'fqdn=~"^fe-[0-9].*"'),
    networkPanel('Fe Pages (HAProxy) Data Transfer / 24h', 'fqdn=~"^fe-pages-[0-9].*"'),
  ], cols=3, rowHeight=7, startRow=4)
)
.addPanel(
  row.new(title='Fleet Nodes and Kubernetes Containers'),
  gridPos={ x: 0, y: 5, w: 24, h: 12 },
)
.addPanels(
  layout.grid([
    networkPanelK8s('Git Data Transfer / 24h', 'type="git"'),
    networkPanelK8s('API Data Transfer / 24h', 'type="api"'),
    networkPanelK8s('Web Data Transfer / 24h', 'type="web"'),
    networkPanelK8s('Web Pages Transfer / 24h', 'type="web-pages"'),
  ], cols=4, rowHeight=7, startRow=5)
)
.addPanel(
  row.new(title='Storage Nodes'),
  gridPos={ x: 0, y: 6, w: 24, h: 12 },
)
.addPanels(
  layout.grid([
    networkPanel('File (Gitaly) Data Transfer / 24h', 'type="gitaly"'),
    networkPanel('Patroni  (Database) Data Transfer / 24h', 'type="patroni"'),
    networkPanel('Redis  (All) Data Transfer / 24h', 'type=~"^redis.*"'),
  ], cols=3, rowHeight=7, startRow=6)
)
.addPanel(
  row.new(title='Object Storage'),
  gridPos={ x: 0, y: 8, w: 24, h: 12 },
)
.addPanels(
  layout.grid([
    osPanel('Object Storage by Bucket data transfer / hour'),
  ], cols=1, rowHeight=7, startRow=8)
)
