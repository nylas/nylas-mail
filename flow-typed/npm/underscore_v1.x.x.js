// flow-typed signature: e8dc864bdb2b9d67eb3996c8c96e253b
// flow-typed version: 5592656f34/underscore_v1.x.x/flow_>=v0.13.x

// type definitions for (some of) underscore

declare module "underscore" {
  declare function find<T>(list: T[], predicate: (val: T)=>boolean): ?T;
  declare function findWhere<T>(list: Array<T>, properties: {[key:string]: any}): ?T;
  declare function clone<T>(obj: T): T;

  declare function findIndex<T>(list: T[], predicate: (val: T)=>boolean): number;
  declare function indexOf<T>(list: T[], val: T): number;
  declare function contains<T>(list: T[], val: T, fromIndex?: number): boolean;

  declare function isEqual(a: any, b: any): boolean;
  declare function range(a: number, b: number): Array<number>;
  declare function extend<S, T>(o1: S, o2: T): S & T;

  declare function zip<S, T>(a1: S[], a2: T[]): Array<[S, T]>;

  declare function flatten<S>(a: S[][]): S[];

  declare function each<T>(o: {[key:string]: T}, iteratee: (val: T, key: string)=>void): void;
  declare function each<T>(a: T[], iteratee: (val: T, key: string)=>void): void;

  declare function map<T, U>(a: T[], iteratee: (val: T, n: number)=>U): U[];
  declare function map<K, T, U>(a: {[key:K]: T}, iteratee: (val: T, k: K)=>U): U[];
  declare function pluck(a: Array<any>, propertyName: string): Array <any>;

  declare function reduce<T, MemoT>(a: Array<T>, iterator: (m: MemoT, o: T)=>MemoT, initialMemo?: MemoT): MemoT;
  declare function inject<T, MemoT>(a: Array<T>, iterator: (m: MemoT, o: T)=>MemoT, initialMemo?: MemoT): MemoT;
  declare function foldl<T, MemoT>(a: Array<T>, iterator: (m: MemoT, o: T)=>MemoT, initialMemo?: MemoT): MemoT;
  declare function reduceRight<T, MemoT>(a: Array<T>, iterator: (m: MemoT, o: T)=>MemoT, initialMemo?: MemoT): MemoT;
  declare function foldRight<T, MemoT>(a: Array<T>, iterator: (m: MemoT, o: T)=>MemoT, initialMemo?: MemoT): MemoT;

  declare function object<T>(a: Array<[string, T]>): {[key:string]: T};
  declare function pairs<T>(o: {[key:string]: T}): Array<[string, T]>;

  declare function every<T>(a: Array<T>, pred: (val: T)=>boolean): boolean;
  declare function all<T>(a: Array<T>, pred: (val: T)=>boolean): boolean;
  declare function some<T>(a: Array<T>, pred: (val: T)=>boolean): boolean;
  declare function any<T>(a: Array<T>, pred: (val: T)=>boolean): boolean;

  declare function intersection<T>(...arrays: Array<Array<T>>): Array<T>;
  declare function difference<T>(array: Array<T>, ...others: Array<Array<T>>): Array<T>;

  declare function initial<T>(a: Array<T>, n?: number): Array<T>;
  declare function rest<T>(a: Array<T>, index?: number): Array<T>;

  declare function first<T>(a: Array<T>, n: number): Array<T>;
  declare function first<T>(a: Array<T>): T;
  declare function head<T>(a: Array<T>, n: number): Array<T>;
  declare function head<T>(a: Array<T>): T;
  declare function take<T>(a: Array<T>, n: number): Array<T>;
  declare function take<T>(a: Array<T>): T;
  declare function last<T>(a: Array<T>, n: number): Array<T>;
  declare function last<T>(a: Array<T>): T;
  declare function sample<T>(a: T[]): T;

  declare function sortBy<T>(a: T[], property: any): T[];
  declare function sortBy<T>(a: T[], iteratee: (val: T)=>any): T[];

  declare function uniq<T>(a: T[]): T[];
  declare function compact<T>(a: Array<?T>): T[];
  declare function filter<T>(o: {[key:string]: T}, pred: (val: T, k: string)=>boolean): T[];
  declare function filter<T>(a: T[], pred: (val: T, k: string)=>boolean): T[];

  declare function select<T>(o: {[key:string]: T}, pred: (val: T, k: string)=>boolean): T[];
  declare function select<T>(a: T[], pred: (val: T, k: string)=>boolean): T[];

  declare function reject<T>(o: {[key:string]: T}, pred: (val: T, k: string)=>boolean): T[];
  declare function reject<T>(a: T[], pred: (val: T, k: string)=>boolean): T[];

  declare function without<T>(a: T[], ...values: T[]): T[];

  declare function isEmpty(o: any): boolean;

  declare function groupBy<T>(a: Array<T>, iteratee: (val: T, index: number)=>any): {[key:string]: T[]};

  declare function min<T>(a: Array<T>|{[key:any]: T}): T;
  declare function max<T>(a: Array<T>|{[key:any]: T}): T;

  declare function has(o: any, k: any): boolean;
  declare function isArray(a: any): boolean;
  declare function keys<K, V>(o: {[key: K]: V}): K[];
  declare function values<K, V>(o: {[key: K]: V}): V[];
  declare function flatten(a: Array<any>): Array<any>;

  declare function pick(o: any, ...keys: any): any;
  declare function pick<T>(o: T, fn: (v: any, k: any, o: T) => boolean): any;
  declare function omit(o: any, ...keys: Array < string > ): any;
  declare function omit<T>(o: any, fn: (v: any, k: any, o: T) => boolean): any;

  // TODO: improve this
  declare function chain<S>(obj: S): any;

  declare function throttle<T>(fn: T, wait: number, options?: {leading?: boolean, trailing?: boolean}): T;
  declare function debounce<T>(fn: T, wait: number, immediate?: boolean): T;
  declare function defer(fn: Function, ...arguments: Array<any>): void;
}

