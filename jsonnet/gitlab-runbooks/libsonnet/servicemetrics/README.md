# ServiceMetrics

This module contains code to generate key service metric indicators
at different burn rates.

The metrics are:

* Apdex (for latency)
* Requests (per second)
* Error Rates (per second)
* Saturation and Utilization metrics (as a ratio)

This module should not generate metrics for GitLab.com specifically. Keep
GitLab.com specific configuration in the metrics catalog itself when possible.

## SLI ownership

Each SLI can be owned by a team and/or a `feature_category`.

Teams are defined in [`service-catalog.yml`](https://gitlab.com/gitlab-com/runbooks/blob/master/services/service-catalog.yml).

Feature categories are defined in the stage categories stanza in the [`stages.yml` file](https://gitlab.com/gitlab-com/www-gitlab-com/blob/master/data/stages.yml).
