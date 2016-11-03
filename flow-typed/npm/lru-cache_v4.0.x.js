// flow-typed signature: 2b18e21f9bd758821dbc1c72e8aef6bf
// flow-typed version: 94e9f7e0a4/lru-cache_v4.0.x/flow_>=v0.26.0

declare module 'lru-cache' {

  declare type LRUCache<K, V> = {
    set: (key: K, value: V, maxAge?: number) => void;
    get: (key: K) => V;
    peek: (key: K) => V;
    del: (key: K) => void;
    reset: () => void;
    has: (key: K) => boolean;
    // TODO add the rest of the things documented at https://www.npmjs.com/package/lru-cache
  };

  declare type Options<K, V> = {
    max?: number;
    maxAge?: number;
    length?: (value: V, key: K) => number;
    dispose?: (key: K, value: V) => void;
    stale?: boolean;
  };

  // TODO You can supply just an integer (max size), or even nothing at all.
  declare var exports: <K, V>(options: Options<K, V>) => LRUCache<K, V>;
}
