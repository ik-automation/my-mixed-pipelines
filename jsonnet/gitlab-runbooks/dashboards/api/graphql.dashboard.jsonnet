local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local selector = {
  environment: '$environment',
  controller: 'GraphqlController',
  stage: '$stage',
};

local selectorString = selectors.serializeHash(selector);

basic.dashboard('GraphQL', tags=['type:api', 'detail'])
.addTemplate(templates.stage)
.addPanels(
  layout.grid([
    basic.text(
      title='Description',
      content=|||
        # GraphQL Observability (WIP)

        This dashboard will help us monitor and observe the effects of GraphQL across GitLab. For more
        information, please see:

        - [Relevant epic](https://gitlab.com/groups/gitlab-org/-/epics/5841)
        - [Architecture blueprint](https://docs.gitlab.com/ee/architecture/blueprints/graphql_api/)
      |||,
    ),
    basic.timeseries(
      stableId='request-rate',
      title='Request Rate',
      query='sum(avg_over_time(controller_action:gitlab_transaction_duration_seconds_count:rate1m{%s}[$__interval]))' % selectorString,
      legendFormat='{{ action }}',
      format='ops',
      yAxisLabel='Requests per Second',
    ),
  ])
)
.trailer()
+ {
  links+: [
    platformLinks.dynamicLinks('API Detail', 'type:api'),
  ],
}
