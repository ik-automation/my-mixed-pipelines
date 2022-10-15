# Alertmanager configuration

We manage our Alertmanager configuration here using jsonnet. The resultant
Kubernetes secret object is uploaded, and is consumed by
[the Prometheus operator deployment](https://gitlab.com/gitlab-com/gl-infra/k8s-workloads/gitlab-helmfiles/-/tree/master/releases/30-gitlab-monitoring).

The CI jobs for this are run on ops.gitlab.net where the variables are configured.
See: https://ops.gitlab.net/gitlab-com/runbooks/-/settings/ci_cd

## Variables

### `ALERTMANAGER_SECRETS_FILE`

Type: File

Value: A jsonnet file, based on the dummy-secrets.jsonnet template.

### `SERVICE_KEY`

Type: File

Value: A GCP service key json file.

## CI Jobs

These jobs run in a CI pipeline, view the [.gitlab-ci.yml](../.gitlab-ci.yml) to
determine how this is configured.

To run a manual deploy, you will need a local secrets file with the filename
exported in the `ALERTMANAGER_SECRETS_FILE` variable.

Then remove the lines associated with authenticating and setting up gcloud in the
`update.sh` file.

* Generate the `alertmanager.yml` file.
  * `./generate.sh`
* Validate the `alertmanager.yml` looks reaosnable.
* The contents of this file are visible as a base64 encoded secret, in the
  manifest k8s_alertmanager_secret.yaml.
* When this secret is uploaded to a namespace containing a prometheus operator
  and an Alertmanager CRD (which these days is only the ops GKE cluster's
  monitoring namespace), Alertmanager's config will automatically be updated.
