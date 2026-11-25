---
name: start-issue
description: Issue 番号から、命名規則どおりの作業ブランチ（<リポジトリ名>-i<番号>-<英訳スラッグ>）を main から切って実装を始める。「#12 に着手して」「Issue 12 を始めて」と言われたときに使う。
---

# start-issue — Issue 番号から作業ブランチを切る

このスキルは汎用に書いてある。リポジトリ固有の値は、リポジトリ直下の `AGENTS.md` の「開発フロー」節にある **「スキルが参照する値」表** から読む（`<リポジトリ>`・`<ブランチ接頭辞>`・`<既定ブランチ>`・`<gh>`）。

## 原則

- **1 Issue = 1 ブランチ = 1 PR**。1 つのブランチに複数の Issue を混ぜない
- ブランチは **`<既定ブランチ>`（main）の最新から切る**
- **main へ直接 commit / push しない**。変更は必ずこのスキルで切ったブランチで行い、`open-pr` で PR にする

## 手順

1. **作業場所を確かめる。**
   ```sh
   git rev-parse --is-inside-work-tree      # true であること
   git remote get-url origin                # <リポジトリ> を指していること
   git status --porcelain                   # 空であること
   ```
   git 管理外のスナップショット（`.git` が無い・origin が無い）では使えない。未コミットの変更があるときは、消したり退避したりせず、そのまま止めて PM に報告する。

2. **Issue を読む。**
   ```sh
   <gh> issue view <番号> -R <リポジトリ> --json number,title,state,body,comments
   ```
   - `state` が `OPEN` であること
   - 本文に 背景 / スコープ / 受け入れ条件 / 対象外 があること。欠けていたら着手せず報告する
   - 「確認レベル：大」の Issue は、PM の確認（コメントや指示）が済んでいることを確かめる。済んでいなければ着手しない

3. **ブランチ名を決める**：`<ブランチ接頭辞>-i<番号>-<スラッグ>`
   - スラッグ：Issue タイトルを英訳し、小文字の英数字とハイフンだけにする。動詞から始め、冠詞は省く。3〜6 語・40 文字以内が目安
   - 例：「記録画面のボタンを大きくする」(#12, アプリ) → `kyou-no-kagami-i12-enlarge-record-buttons`
   - 例：「seed ジョブ用の IAM を追加する」(#3, インフラ) → `kyou-no-kagami-infra-i3-add-seed-job-iam`

4. **既存ブランチを確かめる。**
   ```sh
   git branch --list "<ブランチ接頭辞>-i<番号>-*"
   git ls-remote --heads origin "<ブランチ接頭辞>-i<番号>-*"
   ```
   同じ Issue のブランチが既にあれば新しく作らない。そのブランチに切り替えて続きから作業し、そのことを報告する。

5. **main の最新から切る。**
   ```sh
   git fetch origin <既定ブランチ>
   git switch -c <ブランチ名> origin/<既定ブランチ>
   ```
   この時点では push しない（push は `open-pr` で行う）。

6. **報告する**：ブランチ名、Issue の受け入れ条件の要約、実装の方針（3 ファイル以上にまたがるなら `AGENTS.md` に従って計画を先に提示する）。

## してはいけないこと

- main 上で作業・commit する
- 既存ブランチの削除・`git reset --hard`・force push
- Issue の範囲（対象外）に書かれた作業をこのブランチに混ぜる。必要になったら別 Issue の起票候補として報告する
