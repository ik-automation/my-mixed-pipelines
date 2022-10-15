{
  errorLevel(op, value, yaxis='left')::
    self {
      value: value,
      colorMode: 'custom',
      op: op,
      fill: true,
      line: false,
      yaxis: yaxis,
      fillColor: 'rgba(242, 73, 92, 0.5)',
    },
  warningLevel(op, value, yaxis='left')::
    self {
      value: value,
      colorMode: 'custom',
      op: op,
      fill: true,
      line: false,
      yaxis: yaxis,
      fillColor: 'rgba(242, 73, 92, 0.25)',
    },
  optimalLevel(op, value, yaxis='left')::
    self {
      value: value,
      colorMode: 'custom',
      op: op,
      fill: true,
      line: false,
      yaxis: yaxis,
      fillColor: 'rgba(86, 166, 75, 0.25)',
    },
}
