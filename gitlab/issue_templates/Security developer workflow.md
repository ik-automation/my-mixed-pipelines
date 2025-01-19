<!--
# Read me first!

Create this issue under https://gitlab.com/gitlab-org/security/gitlab

Set the title to: `Description of the original issue`
-->

## Prior to starting the security release work

- [ ] Read the [security process for developers] if you are not familiar with it.
- [ ] Make sure the [issue really needs to follow the security release workflow].
- [ ] **IMPORTANT**: Mark this [issue as linked] to the Security Release Tracking Issue. You can find it [here](https://gitlab.com/gitlab-org/gitlab/-/issues?sort=created_date&state=opened&label_name[]=upcoming+security+release). This issue
MUST be linked for the release bot to know that the associated merge requests should be merged for this security release.
- Fill out the [Links section](#links):
  - [ ] Next to **Issue on GitLab**, add a link to the `gitlab-org/gitlab` issue that describes the security vulnerability.
- [ ] Add one of the `~severity::x` labels to the issue and all associated merge requests.
- [ ] If this change affects the public interface (public API or UI) of the product, post in the `#support_gitlab-com` Slack channel  to explain the impact and discuss a mitigation plan for users that might be affected. If you need Support feedback or approval, reach out in `#spt_managers` Slack channel or mention `@gitlab-com/support/managers`.

## Development

- [ ] Run `scripts/security-harness` in your local repository to prevent accidentally pushing to any remote besides `gitlab.com/gitlab-org/security`.
- [ ] Create a new branch prefixing it with `security-`.
- [ ] Create a merge request targeting `master` on `gitlab.com/gitlab-org/security` and use the [Security Release merge request template].

After your merge request has been approved according to our [approval guidelines] and by a team member of the AppSec team, you're ready to prepare the backports

## Backports

- [ ] Once the MR is ready to be merged, create MRs targeting the latest 3 stable branches
   * The 3 stable branches correspond to the versions in the title of the Security Release Tracking Issue.
   * At this point, it might be easy to squash the commits from the MR into one
   * You can use the script `bin/secpick` instead of the following steps, to help you cherry-picking. See the [secpick documentation]
- [ ] Create each MR targeting the stable branch `X-Y-stable`, using the [Security Release merge request template].
   * Every merge request will have its own set of to-dos, so make sure to complete those.
- [ ] On the "Related merge requests" section, ensure that `4` merge requests are associated: The one targeting `master` and the `3` backports.
- [ ] If this issue requires less than `4` merge requests, post a message on the Security Release Tracking Issue and ping the Release Managers.

## Documentation and final details

- [ ] Ensure the [Links section](#links) is completed.
- [ ] Add the GitLab [versions](https://gitlab.com/gitlab-org/release/docs/-/blob/master/general/security/developer.md#versions-affected) and editions affected to the [details section](#details)
  * The Git history of the files affected may help you associate the issue with a [release](https://about.gitlab.com/releases/)
- [ ] Fill in any upgrade notes that users may need to take into account in the [details section](#details)
- [ ] Add Yes/No and further details if needed to the migration and settings columns in the [details section](#details)
- [ ] Add the nickname of the external user who found the issue (and/or HackerOne profile) to the Thanks row in the [details section](#details)
- [ ] If this includes a breaking change, make sure it is mentioned for the relevant versions in [`doc/update/index.md`](https://gitlab.com/gitlab-org/security/gitlab/-/blob/master/doc/update/index.md#version-specific-upgrading-instructions)

## Summary

### Links

| Description | Link |
| -------- | -------- |
| Issue on [GitLab](https://gitlab.com/gitlab-org/gitlab/issues) | #TODO  |
| CVE ID request on [`gitlab-org/cves`](https://gitlab.com/gitlab-org/cves/-/issues?sort=created_date&state=opened) | #TODO for AppSec  |

### Details

| Description | Details | Further details|
| -------- | -------- | -------- |
| Versions affected | X.Y  | |
| GitLab EE only | Yes/No | |
| Upgrade notes | | |
| GitLab Settings updated | Yes/No| |
| Migration required | Yes/No | |
| Thanks | | |

[security process for developers]: https://gitlab.com/gitlab-org/release/docs/blob/master/general/security/developer.md
[secpick documentation]: https://gitlab.com/gitlab-org/release/docs/-/blob/master/general/security/utilities/secpick_script.md
[security Release merge request template]: https://gitlab.com/gitlab-org/security/gitlab/blob/master/.gitlab/merge_request_templates/Security%20Release.md
[approval guidelines]: https://docs.gitlab.com/ee/development/code_review.html#approval-guidelines
[issue as linked]: https://docs.gitlab.com/ee/user/project/issues/related_issues.html#add-a-linked-issue
[issue really needs to follow the security release workflow]: https://gitlab.com/gitlab-org/release/docs/-/blob/master/general/security/developer.md#making-sure-the-issue-needs-to-follow-the-security-release-workflow

/label ~security
