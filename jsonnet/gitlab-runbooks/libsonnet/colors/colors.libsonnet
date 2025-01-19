local rgba(red, green, blue, alpha) =
  {
    red: red,
    green: green,
    blue: blue,
    alpha: alpha,
    toRGBA():: 'rgba(%(red)d,%(green)d,%(blue)d,%(alpha).2f)' % self,
    toHex():: '#%(red)02x%(green)02x%(blue)02x' % self,
    toString()::
      if alpha == 1 then
        self.toHex()
      else
        self.toRGBA(),
  };

local hex(string) =
  local s = std.lstripChars(string, '#');
  local value = std.parseHex(s);
  local red = (value >> 16) % 256;
  local green = (value >> 8) % 256;
  local blue = value % 256;
  rgba(red, green, blue, 1);

// Returns an array of colors in a linear gradient
local linearGradient(start, end, steps) =

  if steps == 1 then
    [start]
  else if steps == 2 then
    [start, end]
  else
    local deltaRed = (end.red - start.red) / (steps - 1);
    local deltaGreen = (end.green - start.green) / (steps - 1);
    local deltaBlue = (end.blue - start.blue) / (steps - 1);
    local deltaAlpha = (end.alpha - start.alpha) / (steps - 1);

    (
      [
        rgba(
          red=start.red + i * deltaRed,
          green=start.green + i * deltaGreen,
          blue=start.blue + i * deltaBlue,
          alpha=start.alpha + i * deltaAlpha,
        )
        for i in std.range(0, steps - 2)
      ] +
      [end]
    );

{
  hex(string):: hex(string),
  rgba(red, green, blue, alpha):: rgba(red, green, blue, alpha),
  linearGradient:: linearGradient,

  // Colors taken from Grafana color picker palettes
  GREEN:: hex('#73BF69'),
  BLUE:: hex('#5794F2'),
  ORANGE:: hex('#FF9830'),
  RED:: hex('#F2495C'),
  YELLOW:: hex('#FADE2A'),
  PURPLE:: hex('#B877D9'),
}
