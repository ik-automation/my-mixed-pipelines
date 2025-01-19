// https://itnext.io/how-to-describe-100-gitlab-jobs-in-100-lines-using-jsonnet-4e19a4d5bca
// jsonnet example.jsonnet
local job = {
  script: ['echo 123'],
  only: { refs: ['tags'] },
};
local ref(x) = { only+: { refs+: [x] } };

job + ref('prod')
