---
title: "[TS] クラスのコンストラクタを Awaitable にする"
emoji: "🗒"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["typescript", "javascript", "promise"]
published: true
---

## はじめに

TypeScript のコンストラクタで非同期処理を行い、インスタンスを直接 `await` したいことってありますよね？
私は別にありません
```typescript
// 例: DB への接続
const db = await new Db(url)
```

これについて、`Promise` を継承することで実現できるのではと思い試してみました

## PromiseLikeBase

まず「コンストラクタの返り値が Awaitable なクラス」を書くにあたって生じるボイラープレートを汎用クラスとして定義します

### 実装

```typescript
class PromiseLikeBase<T> extends Promise<T> {
  #promise: Promise<T>
  constructor(tGetter: () => Promise<T>) {
    const {
      promise: tPromise,
      resolve: tResolve,
      reject: tReject,
    } = Promise.withResolvers<T>()
    super((resolve, reject) => tPromise.then(resolve).catch(reject))

    this.#promise = tGetter()
    this.#promise.then(tResolve)
    this.#promise.catch(tReject)
  }

  then: Promise<T>['then'] = (...args) => this.#promise.then(...args)
  catch: Promise<T>['catch'] = (...args) => this.#promise.catch(...args)
  finally: Promise<T>['finally'] = (...args) => this.#promise.finally(...args)
}
```

### 解説

#### constructor
`constructor` では与えられた非同期関数を実行し `this.#promise` に代入。更に自身が解決されるタイミングを `this.#promise` と同期させています
`super` を呼ぶ前に `this` にアクセスすることができないので `Promise.withResolvers` を使っていますが、もしその制限が無ければ下記のようになります

```typescript
constructor(tGetter: () => Promise<T>) {
  this.#promise = tGetter()
  super((resolve, reject) => this.#promise.then(resolve).catch(reject))
}
```

#### then / catch / finally
`then`/`catch`/`finally` で `this.#promise` のメソッドを呼ぶようにしていますが
これは `super.then<R1, R2>` を呼ぶとコンストラクタの第一引数に
```typescript
(resolve: (value: T) => void, reject: (reason: any) => void) => void
```
が渡され、`tGetter` として扱われて変なことになるためです

コンストラクタ側で分岐することでメソッドの再実装をせずに動かすこともできなくはないですが
型に無理がいったり不要な引数を取る必要が出たりと主観的に好ましくないコードになります
```typescript
// PromiseLikeBase を継承したクラス側で
// `super(() => someAsyncFunc(arg1), arg1)` のように呼び出してもらう
constructor(tGetter: () => Promise<T>, firstArg: any) {
  // then 経由の呼び出しでは第一引数の関数の文字列が `function () { [native code] }` となる
  if (firstArg?.toString().includes('native code')) {
    super(firstArg)
    return
  }
  // 省略
}
```

## DB 接続 (モック)

これを使用して DB への接続を模したコードを書きます

### 実装

```typescript
async function sleep(ms: number) {
  await new Promise((resolve) => setTimeout(resolve, ms))
}

class _Db {
  async execute(query: string) { // moc
    await sleep(1000)
    console.log({ query })
  }
}

class Db extends PromiseLikeBase<_Db> {
  static async #connect(url: string) { // moc
    await sleep(1000)
    console.log({ url })
    return new _Db()
  }
  constructor(url: string) {
    super(() => Db.#connect(url))
  }
}

const db = await new Db('test://url') // -> { url: "test://url" }
db.execute('SELECT * FROM table;') // -> { query: "SELECT * FROM table;" }
```

### 解説

`await new Db('test://url')` のようにコンストラクタを直接 `await` し、返ってきた値のメソッドを呼び出すことができました

`await` する前とした後で同じクラスを使い回す方法も考えたのですが、補完候補に `then` 等が入るのが煩わしそうなので分けることにしました

## 結論

ここまでしてコンストラクタを直接 `await` する必要性を感じなかったので、おとなしく static ファクトリーメソッドでも作った方が良いと思います

---

:::details 余談

`Symbol.species` を使うことで `PromiseLikeBase` をシンプルに記述できますが、`Symbol.species` は廃止が検討されているのでメインのサンプルコードとしては採用しませんでした

```typescript
class PromiseLikeBase<T> extends Promise<T> {
  constructor(tGetter: () => Promise<T>) {
    super((resolve, reject) => tGetter().then(resolve).catch(reject))
  }

  static get [Symbol.species]() {
    return Promise
  }
}
```
:::

