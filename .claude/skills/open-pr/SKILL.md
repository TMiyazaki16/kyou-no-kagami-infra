---
name: open-pr
description: Issue ブランチの変更を検証 → commit → push し、Closes 行（Issue 番号）とテスト・ビルド結果を書いた PR を gh CLI で作る。「PR を出して」「プルリクを作って」と言われたとき、実装が受け入れ条件を満たしたときに使う。マージはしない。
---

# open-pr — commit → push → PR 作成

このスキルは汎用に書いてある。リポジトリ固有の値は、リポジトリ直下の `AGENTS.md` の「開発フロー」節にある **「スキルが参照する値」表** から読む（`<リポジトリ>`・`<ブランチ接頭辞>`・`<既定ブランチ>`・`<gh>`・`<検証スキル>`・`<変更禁止パス>`）。

## 原則

- PR には **`Closes #<番号>`** と **テスト・ビルド結果** を必ず書く
- **マージは PM が行う。** Claude は `gh pr merge` を実行しない。自分の PR を approve しない
- main へ直接 push しない。force push しない

## 手順

1. **ブランチを確かめる。**
   ```sh
   git branch --show-current     # <ブランチ接頭辞>-i<番号>-... であること。main なら止める
   ```
   ブランチ名から Issue 番号を取り、`<gh> issue view <番号> -R <リポジトリ>` で受け入れ条件を読み直す。

2. **検証する**：`<検証スキル>` を実行し、すべて通ることを確かめる。通らなければ PR を作らず、失敗内容を報告する（PM が「途中経過を draft で」と指示したときだけ `--draft` で作り、未通過を本文に明記する）。

3. **差分を点検する。**
   ```sh
   git status
   git diff
   git diff --name-only origin/<既定ブランチ>...HEAD
   ```
   - `<変更禁止パス>`（例：`.github/workflows/`）が含まれていたら止めて報告する
   - 秘密を含むファイル（`.env`、`*.tfvars`、`backend.hcl`、`*.tfplan`、鍵 JSON、DB ファイル、トークン）を含めない
   - Issue の「対象外」に当たる変更、無関係な整形差分を含めない

4. **commit する。** `git add -A` / `git add .` は使わず、パスを指定して stage する。
   ```sh
   git add <path> ...
   git commit -m "<変更の要約> (#<番号>)" -m "<補足（何を・なぜ）>"
   ```
   作業環境が commit の署名行（Co-Authored-By など）を指定していれば、それに従って末尾に付ける。

5. **push する。**
   ```sh
   git push -u origin <ブランチ名>
   ```
   拒否されたら force せず、原因（main の更新・権限）を調べて報告する。

6. **PR を作る**（本文は一時ファイルに書いて `--body-file` で渡す）。
   ```sh
   BODY=$(mktemp)
   cat > "$BODY" <<'EOF'
   （下のテンプレを埋めた本文）
   EOF
   <gh> pr create -R <リポジトリ> --base <既定ブランチ> --head <ブランチ名> \
     --title "<Issue のタイトル>" --body-file "$BODY"
   rm -f "$BODY"
   ```

7. **CI を確認して報告する。**
   ```sh
   <gh> pr checks <PR番号> -R <リポジトリ>
   ```
   失敗していたらログ（`<gh> run view <run-id> --log-failed -R <リポジトリ>`）を読み、原因と対処案を報告する。ワークフローの再実行・変更はしない。
   報告には PR の URL、CI の状態、PM に見てほしい点を書き、「マージは PM の判断待ち」と明記する。

## PR 本文テンプレ

```markdown
Closes #<番号>

## 変更内容
- <何を変えたか。ファイル単位で短く>

## 受け入れ条件の確認
- [x] <Issue の受け入れ条件を転記> — <どう確かめたか>
- [ ] <満たせなかった条件があれば、理由>

## テスト・ビルド結果
<検証スキルの報告をそのまま貼る：実行したコマンド、件数（例：Ran 68 tests … OK (skipped=1)）、ビルド・fmt・validate の結果>

## 確認してほしいこと / 未実施
- <PM に判断してほしい点、実行できなかった検証とその理由>
```

- 画面の変更があるときはスクリーンショットの保存先と、見てほしい画面を書く。gh CLI では画像を PR 本文に添付できないので、共有方法は PM に相談する
- 未実施の検証を実施済みと書かない

## してはいけないこと

- `gh pr merge`・自分の PR への approve・ブランチ保護の変更
- main への push、force push、`git reset --hard`
- `<変更禁止パス>` の変更を含む PR
