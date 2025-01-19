# Service Catalog

More information about the service catalog can be found in the [Service Inventory Catalog page](https://about.gitlab.com/handbook/engineering/infrastructure/library/service-inventory-catalog/).

The `stage-group-mapping.jsonnet` file is generated from
[`stages.yml`](https://gitlab.com/gitlab-com/www-gitlab-com/-/blob/master/data/stages.yml)
in the handbook by running `scripts/update-stage-groups-feature-categories`.

## Teams.yml

The `teams.yml` file can contain a definition of a team responsible
for a certain service or component (SLI). Possible configuration keys
are:

- `product_stage_group`: The name of the stage group, if this team is
  a product stage group defined in [`stages.yml`](https://gitlab.com/gitlab-com/www-gitlab-com/-/blob/master/data/stages.yml).
- `ignored_components`: If the team is a stage group, this key can be
  used to list components that should not feed into the stage group's
  error budget. The recordings for the group will continue for these
  components. But the component will not be included in error budgets
  in infradev reports, Sisense, or dashboards displaying the error
  budget for stage groups.
- `slack_alerts_channel`: The name of the Slack channel (without `#`)
  that the team would like to receive alerts in. Read [more about alerting](../docs/uncategorized/alert-routing.md).
- `send_slo_alerts_to_team_slack_channel`: `true` or `false`. If the
  group would like to receive alerts for [feature
  categories](https://docs.gitlab.com/ee/development/feature_categorization/)
  they own.
