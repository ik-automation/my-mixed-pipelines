local colors = import 'colors.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testHex: { actual: colors.hex('#010203'), expect: colors.rgba(1, 2, 3, 1) },
  testGreen: { actual: colors.GREEN.toString(), expect: '#73bf69' },
  testRGBABlackToString: { actual: colors.rgba(0, 0, 0, 0).toString(), expect: 'rgba(0,0,0,0.00)' },
  testRGBABlueToString: { actual: colors.rgba(0, 0, 255, 1).toString(), expect: '#0000ff' },
  testRGBARedToString: { actual: colors.rgba(255, 0, 0, 0.5).toString(), expect: 'rgba(255,0,0,0.50)' },

  // How this linear gradient looks: https://colorhunt.co/palette/225770
  testLinearGradientBlueToYellow: {
    actual: std.map(function(x) x.toString(), colors.linearGradient(colors.BLUE, colors.YELLOW, 4)),
    expect: [
      colors.BLUE.toString(),
      '#8dacaf',
      '#c3c56c',
      colors.YELLOW.toString(),
    ],
  },
})
