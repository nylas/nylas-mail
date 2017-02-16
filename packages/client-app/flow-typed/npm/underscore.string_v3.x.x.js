// flow-typed signature: 58352c9fe022cee660bb0c1dc772d2b0
// flow-typed version: 94e9f7e0a4/underscore.string_v3.x.x/flow_>=v0.25.x

declare module "underscore.string" {

  declare type $npm$wrap$options = {
    width?: number,
    seperator?: string,
    trailingSpaces?: boolean,
    cut?: boolean,
    preserveSpaces?: boolean,
  };
  declare type $npm$pad$type = 'left' | 'right' | 'both';

  declare class Chain {
    levenshtein(string2: string): number;
    capitalize(lowercaseRest?: boolean): Chain;
    decapitalize(): Chain;
    chop(step: number): Array<string>;
    clean(): Chain;
    swapCase(): Chain;
    include(substring: string): boolean;
    contains(substring: string): boolean; // Alias
    count(substring: string): number;
    escapeHTML(): Chain;
    unescapeHTML(): Chain;
    insert(index: number, substring: string): Chain;
    replaceAll(find: string, replace: string, ignorecase?: boolean): Chain;
    isBlank(): boolean;
    join(...strings: Array<string>): Chain,
    lines(): Array<string>;
    wrap(options: $npm$wrap$options): Chain;
    dedent(pattern?: string): Chain;
    reverse(): Chain;
    splice(index: number, howmany: number, substring: string): Chain;
    startsWith(starts: string, position?: number): boolean;
    endsWith(ends: string, position?: number): boolean;
    pred(): Chain;
    succ(): Chain;
    titleize(): Chain;
    camelize(decapitalize?: boolean): Chain;
    camelcase(decapitalize?: boolean): Chain, // Alia;
    classify(): Chain;
    underscored(): Chain;
    dasherize(): Chain;
    humanize(): Chain;
    trim(characters?: string): Chain;
    strip(characters?: string): Chain, // Alia;
    ltrim(characters?: string): Chain;
    lstrip(characters?: string): Chain, // Alia;
    rtrim(characters?: string): Chain;
    rstrip(characters?: string): Chain, // Alia;
    truncate(length: number, truncateString?: string): Chain;
    prune(length: number, pruneString: string): Chain;
    words(delimiter: string|RegExp): Array<string>;
    sprintf(...arguments: Array<*>): Chain;
    pad(length: number, padStr?: string, type?: $npm$pad$type): Chain;
    lpad(length: number, padStr?: string): Chain;
    rjust(length: number, padStr?: string): Chain, // Alia;
    rpad(length: number, padStr?: string): Chain;
    ljust(length: number, padStr?: string): Chain, // Alia;
    lrpad(length: number, padStr?: string): Chain;
    center(length: number, padStr?: string): Chain, // Alia;
    toNumber(decimals?: number): number;
    strRight(pattern: string): Chain;
    strRightBack(pattern: string): Chain;
    strLeft(pattern: string): Chain;
    strLeftBack(pattern: string): Chain;
    stripTags(): Chain;
    // --
    repeat(count: number, separator?: string): Chain,
    surround(wrap: string): Chain,
    quote(quoteChar?: string): Chain,
    q(quoteChar?: string): Chain, // Alias
    unquote(quoteChar?: string): Chain,
    slugify(): Chain,
    naturalCmp(string2: string): number,
    toBoolean(truthy?: Array<string|RegExp>, falsy?: Array<string|RegExp>): ?boolean,
    toBool(truthy?: Array<string|RegExp>, falsy?: Array<string|RegExp>): ?boolean, // Alias
    map(iteratee: (character: string) => string): Chain,

    // native Javascript string methods
    toUpperCase(): Chain,
    toLowerCase(): Chain,
    split(separator?: string, limit?: number): Array<string>,
    replace(pattern: string|RegExp, replacement: string|((...params: Array<string|number>) => string)): Chain,
    slice(beginSlice: number, endSlice?: number): Chain,
    substring(indexStart: number, indexStart?: number): Chain,
    substr(start: number, length?: number): Chain,
    concat(...params: Array<string>): Chain,

    // Chain specific methods
    tap(fn: (string: string) => string): Chain;
    value(): string;
  }

  declare module.exports: {
    // If we're called, we're a function that returns an instance of Chain
    (str: string): Chain,

    // Otherwise lots of "static" methods...
    numberFormat(number: number, decimals?: number, decimalSeparator?: string, orderSeparator?: string): string,
    levenshtein(string1: string, string2: string): number,
    capitalize(string: string, lowercaseRest?: boolean): string,
    decapitalize(string: string): string,
    chop(string: string, step: number): Array<string>,
    clean(string: string): string,
    swapCase(string: string): string,
    include(string: string, substring: string): boolean,
    contains(string: string, substring: string): boolean, // Alias
    count(string: string, substring: string): number,
    escapeHTML(string: string): string,
    unescapeHTML(string: string): string,
    insert(string: string, index: number, substring: string): string,
    replaceAll(string: string, find: string, replace: string, ignorecase?: boolean): string,
    isBlank(string: string): boolean,
    join(separator: string, ...strings: Array<string>): string,
    lines(string: string): Array<string>,
    wrap(string: string, options: $npm$wrap$options): string,
    dedent(string: string, pattern?: string): string,
    reverse(string: string): string,
    splice(string: string, index: number, howmany: number, substring: string): string,
    startsWith(string: string, starts: string, position?: number): boolean,
    endsWith(string: string, ends: string, position?: number): boolean,
    pred(string: string): string,
    succ(string: string): string,
    titleize(string: string): string,
    camelize(string: string, decapitalize?: boolean): string,
    camelcase(string: string, decapitalize?: boolean): string, // Alias
    classify(string: string): string,
    underscored(string: string): string,
    dasherize(string: string): string,
    humanize(string: string): string,
    trim(string: string, characters?: string): string,
    strip(string: string, characters?: string): string, // Alias
    ltrim(string: string, characters?: string): string,
    lstrip(string: string, characters?: string): string, // Alias
    rtrim(string: string, characters?: string): string,
    rstrip(string: string, characters?: string): string, // Alias
    truncate(string: string, length: number, truncateString?: string): string,
    prune(string: string, length: number, pruneString: string): string,
    words(string: string, delimiter: string|RegExp): Array<string>,
    sprintf(string: string, ...arguments: Array<*>): string,
    pad(string: string, length: number, padStr?: string, type?: $npm$pad$type): string,
    lpad(string: string, length: number, padStr?: string): string,
    rjust(string: string, length: number, padStr?: string): string, // Alias
    rpad(string: string, length: number, padStr?: string): string,
    ljust(string: string, length: number, padStr?: string): string, // Alias
    lrpad(string: string, length: number, padStr?: string): string,
    center(string: string, length: number, padStr?: string): string, // Alias
    toNumber(string: string, decimals?: number): number,
    strRight(string: string, pattern: string): string,
    strRightBack(string: string, pattern: string): string,
    strLeft(string: string, pattern: string): string,
    strLeftBack(string: string, pattern: string): string,
    stripTags(string: string): string,
    toSentence(array: Array<string>, delimiter?: string, lastDelimiter?: string): string,
    toSentenceSerial(array: Array<string>, delimiter?: string, lastDelimiter?: string): string,
    repeat(string: string, count: number, separator?: string): string,
    surround(string: string, wrap: string): string,
    quote(string: string, quoteChar?: string): string,
    q(string: string, quoteChar?: string): string, // Alias
    unquote(string: string, quoteChar?: string): string,
    slugify(string: string): string,
    naturalCmp(string1: string, string2: string): number,
    toBoolean(string: string, truthy?: Array<string|RegExp>, falsy?: Array<string|RegExp>): ?boolean,
    toBool(string: string, truthy?: Array<string|RegExp>, falsy?: Array<string|RegExp>): ?boolean, // Alias
    map(string: string, iteratee: (character: string) => string): string
  }
}
