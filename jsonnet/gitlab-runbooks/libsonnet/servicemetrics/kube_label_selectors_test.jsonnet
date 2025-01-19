local underTest = import './kube_label_selectors.libsonnet';
local test = import 'test.libsonnet';

local defaultSelector = underTest().init('type', 'tier');
local selector2 = underTest(
  podSelector={ pod: 'p', namespace: 'n', app: 'l' },
  hpaSelector={ horizontalpodautoscaler: 'h', namespace: 'n', app: 'l' },
  nodeSelector={ node: 'n', namespace: 'n', app: 'l' },
  ingressSelector={ ingress: 'i', namespace: 'n', app: 'l' },
  deploymentSelector={ deployment: 'd', namespace: 'n', app: 'l' },
).init('type', 'tier');

test.suite({
  testDefaultPodSelector: {
    actual: defaultSelector.getPromQLSelector('pod'),
    expect: { label_type: 'type' },
  },

  testDefaultHPASelector: {
    actual: defaultSelector.getPromQLSelector('hpa'),
    expect: { label_type: 'type' },
  },

  testDefaultNodeSelector: {
    actual: defaultSelector.getPromQLSelector('node'),
    expect: null,
  },

  testDefaultIngressSelector: {
    actual: defaultSelector.getPromQLSelector('ingress'),
    expect: { label_type: 'type' },
  },

  testDefaultDeploymentSelector: {
    actual: defaultSelector.getPromQLSelector('deployment'),
    expect: { label_type: 'type' },
  },

  testPodSelector: {
    actual: selector2.getPromQLSelector('pod'),
    expect: { label_app: 'l', namespace: 'n', pod: 'p' },
  },

  testHPASelector: {
    actual: selector2.getPromQLSelector('hpa'),
    expect: { horizontalpodautoscaler: 'h', label_app: 'l', namespace: 'n' },
  },

  testNodeSelector: {
    actual: selector2.getPromQLSelector('node'),
    expect: { label_app: 'l', namespace: 'n', node: 'n' },
  },

  testIngressSelector: {
    actual: selector2.getPromQLSelector('ingress'),
    expect: { ingress: 'i', label_app: 'l', namespace: 'n' },
  },

  testDeploymentSelector: {
    actual: selector2.getPromQLSelector('deployment'),
    expect: { deployment: 'd', label_app: 'l', namespace: 'n' },
  },

  testWrongIdentitySelectors: {
    actual: underTest(podSelector={ horizontalpodautoscaler: 'p', namespace: 'n', app: 'l' })
            .init('type', 'tier')
            .getPromQLSelector('pod'),
    // horizontalpodautoscaler is an identity for hpa, not for pod
    expect: { label_horizontalpodautoscaler: 'p', label_app: 'l', namespace: 'n' },
  },
})
