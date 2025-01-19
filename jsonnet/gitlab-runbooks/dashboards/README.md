# Dashboard Source

This folder is used to keep the source for some of our Grafana dashboards, checked into, and managed by, git.

On `master` builds, the dashboards will be uploaded to https://dashboards.gitlab.net. Any local changes to these dashboards on
the Grafana instance will be overwritten.

The dashboards are kept in [`grafonnet`](https://github.com/grafana/grafonnet-lib) format, which is based on the [jsonnet template language](https://jsonnet.org/).

# File nomenclature

We utilize the following file format: `dashboards/<service name, aka type>/<dashboard name>.dashboard.jsonnet`

Using this consistent schema makes URLs consistent, etc.

Example, the Container Registry is of service type `registry`.  Therefore,
`dashboards/registry/<somedashboard>.dashboard.jsonnet`

# Extending Grafana dashboards

In order to extend Grafana dashboard you don't need to run Grafana locally. The most common scheme for extending dashboards is updating their definitions in your local repository and pushing changes to a testing playground on `dashboards.gitlab.net`.

An alternative way to check simple changes, that does not require installing dependencies on your local machine, is using a Grafana Playground folder. All users with viewer access to dashboards.gitlab.net, (ie, all GitLab team members), have full permission to edit all dashboards in the [Playground Grafana folder](https://dashboards.gitlab.net/dashboards/f/playground-FOR-TESTING-ONLY/playground-for-testing-purposes-only). You can create dashboards in this folder using the Grafana Web UI.

If you, however, need to extend or modify an existing dashboard and create a merge request to persist these modification, you need be able to quickly create a snapshot of a new version of a dashboard to validate your changes. In order to do that you first need to install dependencies required by the [test-dashboard.sh](test-dashboard.sh) script. You will also need to obtain an API token for Grafana from 1Password.

## Install dependencies

Follow the guidelines for setting up your development environment with `asdf` and required plugins as per the guidelines in the [root README.MD](https://gitlab.com/gitlab-com/runbooks/-/blob/master/README.md#developing-in-this-repo) for this repository.

* Ensure that you install `asdf` and plugins for `go-jsonnet` and `jsonnet-bundler`.
* Update vendor dependencies with `jb install`.

## Obtain the Grafana Playground API Key

1. In the 1password Engineering Vault, lookup the API key stored in `dashboards.gitlab.net Grafana Playground API Key`
1. Edit the `dashboards/.env.sh` file and add the following content: `export GRAFANA_API_TOKEN=<1PASSWORD API KEY VALUE>`
1. In your shell, in the `dashboards` directory, run `source .env.sh` to load it.

## Modify a dashboard

In order to modify a dashboard you will need to write code using [Grafonnet library](https://grafana.github.io/grafonnet-lib/) built on top of [Jsonnet](https://jsonnet.org/) syntax. In most cases you will also need to specify a PromQL query to source the data from Prometheus. You can experiment with PromQL using our [Thanos instance](https://thanos.gitlab.net/) or [Grafana playground for Prometheus](https://dashboards.gitlab.net/explore).

## Create a new snapshot of the modified dashboard

1. To upload your dashboard, run `./test-dashboard.sh dashboard-folder-path/file.dashboard.jsonnet`. It will upload the file and return a link to your dashboard.
1. `./test-dashboard.sh -D $dashboard_path` will echo the dashboard JSON for pasting into Grafana.

**Note that the playground and the snapshots are transient. By default, the snapshots will be deleted after 24 hours and the links will expire. Do not include links to playground dashboards in the handbook or other permanent content.**

# Editing Files

* Dashboards should be kept in files with the following name: `/dashboards/[grafana_folder_name]/[name].dashboard.jsonnet`
  * `grafana_folder_name` refers to the grafana folder where the files will be uploaded to. Note that the folder must already be created.
  * These can be created via `./create-grafana-folder.sh <grafana_folder_name> <friendly name>`
  * Example: `./create-grafana-folder.sh registry 'Container Registry'`
  * Note that if a folder already contains the name, it'll need to be removed or
    renamed in order for the API to accept the creation of a new folder
* Obtain a API key to the Grafana instance and export it in `GRAFANA_API_TOKEN`:
  * `export GRAFANA_API_TOKEN=123`
* To upload the files, run `./dashboards/upload.sh`

## Shared Dashboard Definition Files

Its possible to generate multiple dashboards from a single, shared, jsonnet file.

The file should end with `.shared.jsonnet` and the format of the file should be as follows:

```json
{
  "dashboard_uid_1": { /* Dashboard */ },
  "dashboard_uid_2": { /* Dashboard */ },
}
```

## Backups

Dashboards that are not version-controlled in this repo are periodically purged from grafana. In order to recover a deleted dashboard (and commit it into this repo), you can look at the archive in [grafana-dashboards](https://gitlab.com/gitlab-org/grafana-dashboards).

# The `jsonnet` docker image

* Google does not maintain official docker images for jsonnet.
* For this reason, we have a manual build step to build the `registry.gitlab.com/gitlab-com/runbooks/jsonnet:latest` image.
* To update the image, run this job in the CI build manually
