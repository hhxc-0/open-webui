# Merging Open WebUI Upstream

This repository is an Open WebUI fork. Use this guide when merging upstream so
that upstream improvements and fork-specific features both survive.

## Principles

- Treat `HEAD` as the fork (`ours`) and `MERGE_HEAD` as Open WebUI upstream
  (`theirs`). Do not assume either side should win a whole conflict.
- Preserve fork features unless the maintainer explicitly decides to retire
  them. Current examples include native/external web-search modes, raw document
  upload mode, thinking effort, Context view, and reference-chat folder view.
- Prefer upstream's newer surrounding structure and APIs, then reapply the
  fork-specific behavior at the appropriate integration point.
- Ask the maintainer to choose when a conflict changes product behavior, data
  compatibility, security policy, or an intentionally customized translation.
- Do not run `git merge --continue` or create a commit unless requested.

## Before resolving

1. Check the merge state and record the inputs:

   ```bash
   git status
   git rev-parse HEAD MERGE_HEAD
   git merge-base HEAD MERGE_HEAD
   git diff --name-only --diff-filter=U
   ```

2. Identify fork work that occurred after the merge base. This makes it clear
   which behavior must be retained:

   ```bash
   git log --oneline "$(git merge-base HEAD MERGE_HEAD)..HEAD"
   git diff --stat "$(git merge-base HEAD MERGE_HEAD)..HEAD"
   ```

3. Preserve any pre-existing worktree edits. Do not use destructive recovery
   commands such as `git reset --hard` or `git checkout --`.

4. Save the initial conflict-path list outside the repository. Resolved paths
   disappear from `--diff-filter=U`, so this list is needed for focused
   validation later:

   ```bash
   git diff --name-only --diff-filter=U > /tmp/openwebui-merge-conflicts.txt
   ```

## Resolve one conflict deliberately

For each conflicted path, compare all three versions before editing:

```bash
git show :1:path/to/file  # merge base
git show :2:path/to/file  # fork / ours
git show :3:path/to/file  # upstream / theirs
```

Use the following approach:

1. Explain what each side contributes.
2. Choose a structural base—usually upstream for a recently refactored
   component or backend pipeline.
3. Reapply the fork's feature-specific changes, adapting them to the newer
   interfaces rather than copying a partial conflict branch.
4. Review the full enclosing block after editing; conflict hunks can omit
   opening or closing markup that is shared outside the marker.
5. Re-open the resolved block before staging. In particular, look for missing
   object commas, duplicate props/toolbars, and attributes copied into the
   wrong parent element.
6. Stage only the resolved path once it is validated:

   ```bash
   git add -- path/to/file
   ```

## Backend merge rules

- When extracting shared request-preparation helpers, return everything later
  code needs or put it in the established `metadata` object. Do not leave a
  caller referring to a helper-local variable. For example, chat persistence
  must use the normalized `chat_variables` returned in request metadata.
- Keep preview/dry-run paths on the same preparation pipeline as real chat
  completion where that is the feature's purpose.
- Retain upstream access-control, saved-chat-ID, direct-model, and event
  handling changes unless the fork has an intentional replacement.
- When moving upstream request setup into a shared helper, apply the same
  normalization, fallback, model-parameter, and metadata behavior before both
  the real and preview paths diverge. Keep the normalized value in metadata if
  later persistence needs it.
- Compile every changed Python module after resolving it:

  ```bash
  python3 -m py_compile backend/open_webui/main.py
  ```

## Svelte and TypeScript merge rules

- Resolve markup conflicts as complete parent blocks. Partial copy/paste can
  duplicate toolbars or leave unmatched `<div>` tags.
- Parse a changed Svelte component directly; this catches malformed markup even
  when project-wide type checking has unrelated baseline failures:

  ```bash
  node -e "const fs=require('fs'); const {compile}=require('svelte/compiler'); compile(fs.readFileSync('src/lib/components/chat/MessageInput.svelte','utf8'), {generate:'client'});"
  ```

- When upstream replaces a boolean with a mode or enum, update every binding,
  reset, draft-restoration path, submit payload, and component prop. Leaving an
  old reference such as `webSearchEnabled` causes runtime failures or silently
  disables the fork feature.
- After such a migration, search the entire source tree for the retired name.
  A backward-compatible draft-read fallback may be deliberate; active props,
  bindings, payloads, and resets must use the new representation.
- Audit every input variant (main chat, placeholder/new chat, embedded, and
  read-only branches) and every forwarding component. Custom state such as
  `webSearchMode`, `rawDocumentsEnabled`, and `thinkingEffort` must travel
  through the complete chain, including OAuth/tool callbacks where their draft
  state is passed along.
- Keep upstream lifecycle and layout behavior (for example read-only and
  embedded-chat branches), then add fork props such as `webSearchMode`,
  `rawDocumentsEnabled`, and `thinkingEffort` to every relevant input
  variant.
- When compiling all staged Svelte files, skip staged deletions; the staged
  file list can include a component that no longer exists in the worktree. Use
  client code generation rather than parse-only compilation.

## Translation catalogs

- First determine whether the fork intentionally changed the locale file.
- If it did not, take the newer upstream catalog as a whole. This avoids
  dropping large numbers of new or corrected translations.
- If it did, merge parsed JSON keys three ways rather than resolving textual
  hunks. For each key, take the side that changed when the other matches the
  merge base; retain distinct additions from both sides; recurse into objects.
  Ask the maintainer only when both sides changed the same translation value
  differently.
- Use the upstream key order and formatting as the structural base when
  emitting a key-level merge. This retains upstream catalog maintenance and
  avoids noisy catalog-wide reorder diffs.
- Validate each changed catalog:

  ```bash
  python3 -m json.tool src/lib/i18n/locales/<locale>/translation.json > /dev/null
  ```

## Required validation before handoff

Run these after all conflicts are edited and again after staging:

```bash
git diff --check
git diff --cached --check
git diff --name-only --diff-filter=U
git grep -n -E '^(<<<<<<<|=======|>>>>>>>)' -- ':!node_modules' || true
```

Also run focused Python compilation, JSON validation, and direct Svelte parsing
for changed files. Run `npm run check` when practical, but record the result
accurately: this fork may already have broad strict-typing failures. A
project-wide checker with baseline errors is not proof that a resolved component
has a syntax error; save its output and inspect diagnostics only for the paths
recorded before resolution. Direct Svelte compilation remains the syntax check
for those components.

Before handoff, also verify that the final edits reached the index rather than
only the working tree. This is especially important after scripted JSON merges
or formatting passes:

```bash
git diff --name-only              # should be empty unless intentional
git status --porcelain=v1         # inspect for a non-space second status column
git ls-files -u                   # must be empty
```

## Handoff checklist

- [ ] Every conflict path is staged.
- [ ] `git diff --name-only --diff-filter=U` is empty.
- [ ] No conflict markers remain.
- [ ] Whitespace, Python, JSON, and Svelte parse checks pass for changed files.
- [ ] Project-wide validation results and any baseline failures are documented.
- [ ] No merge commit was made unless explicitly requested.

If an uncertainty remains, stop at the staged resolution and ask the
maintainer. Include the file, the competing behaviors, and the impact of each
choice.

