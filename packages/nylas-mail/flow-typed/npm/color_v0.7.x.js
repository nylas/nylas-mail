// flow-typed signature: 33eb6d83c2fd34c39472f855d310100d
// flow-typed version: 94e9f7e0a4/color_v0.7.x/flow_>=v0.23.x

type $npm$color$RGBObject = {
  r: number,
  g: number,
  b: number,
};

type $npm$color$HSLObject = {
  h: number,
  s: number,
  l: number,
};

type $npm$color$HSVObject = {
  h: number,
  s: number,
  v: number,
};

type $npm$color$HWBObject = {
  h: number,
  w: number,
  b: number,
};

type $npm$color$CMYKObject = {
  c: number,
  m: number,
  y: number,
  k: number,
};

declare module 'color' {
  declare class Color {
    (value: $npm$color$RGBObject): Color;
    (value: string): Color;
    (): Color;

    static (value: $npm$color$RGBObject): Color;
    static (value: string): Color;
    static (): Color;

    rgb(r: number, g: number, b: number): Color;
    rgb(rgb: Array<number>): Color;
    rgb(): $npm$color$RGBObject;
    rgbArray(): Array<number>;

    hsl(h: number, s: number, l: number): Color;
    hsl(hsl: $npm$color$HSLObject): Color;
    hsl(): $npm$color$HSLObject;
    hslArray(): Array<number>;

    hsvArray(): Array<number>;
    hsv(h: number, s: number, v: number): Color;
    hsv(hsv: $npm$color$HSVObject): Color;
    hsv(): $npm$color$HSVObject;

    hwb(h: number, w: number, b: number): Color;
    hwb(hwb: $npm$color$HWBObject): Color;
    hwb(): $npm$color$HWBObject;
    hwbArray(): Array<number>;

    cmyk(c: number, m: number, y: number, k: number): Color;
    cmyk(cmyk: $npm$color$CMYKObject): Color;
    cmyk(): $npm$color$CMYKObject;
    cmykArray(): Array<number>;

    alpha(alpha: number): Color;
    alpha(): number;

    red(red: number): Color;
    red(): number;

    green(green: number): Color;
    green(): number;

    blue(blue: number): Color;
    blue(): number;

    hue(hue: number): Color;
    hue(): number;

    saturation(saturation: number): Color;
    saturation(): number;

    saturationv(saturationv: number): Color;
    saturationv(): number;

    lightness(lightness: number): Color;
    lightness(): number;

    whiteness(whiteness: number): Color;
    whiteness(): number;

    blackness(blackness: number): Color;
    blackness(): number;

    cyan(cyan: number): Color;
    cyan(): number;

    magenta(magenta: number): Color;
    magenta(): number;

    yellow(yellow: number): Color;
    yellow(): number;

    black(black: number): Color;
    black(): number;

    clearer(value: number): Color;
    clone(): Color;
    contrast(color: Color): number;
    dark(): bool;
    darken(value: number): Color;
    desaturate(value: number): Color;
    grayscale(): Color;
    hexString(): string;
    hslString(): string;
    hwbString(): string;
    keyword(): ?string;
    light(): bool;
    lighten(value: number): Color;
    luminosity(): number;
    mix(color: Color, value?: number): Color;
    negate(): Color;
    opaquer(value: number): Color;
    percentString(): string;
    rgbString(): string;
    rotate(value: number): Color;
    saturate(value: number): Color;
  }
  declare var exports: typeof Color;
}
