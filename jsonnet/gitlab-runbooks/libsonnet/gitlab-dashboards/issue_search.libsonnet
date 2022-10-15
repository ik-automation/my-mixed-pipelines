local strings = import 'utils/strings.libsonnet';

{
  // Returns an issue search URL on GitLab.com, across the
  // https://gitlab.com/groups/gitlab-com/gl-infra/ group
  buildInfraIssueSearch(labels=[], search=null)::
    local labelsParams = [
      'label_name[]=' + strings.urlEncode(l)
      for l in labels
    ];

    local searchParams =
      if search != null then
        ['search=' + strings.urlEncode(search)]
      else
        [];

    'https://gitlab.com/groups/gitlab-com/gl-infra/-/issues?scope=all&state=all&' + std.join('&', labelsParams + searchParams),
}
