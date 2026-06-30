# 15 — GitLab CI/CD Pipeline (build & publish the installer)

**Status:** Proposed (implement **last** — doc 14 Phase F) · **Applies to:** `solutions-copilot`
repo, `installer/` subfolder · **GitLab:** `gitlab.appian-stratus.com` · **Last updated:** 2026-06-26

> Goal: when we push, GitLab builds (and on a tag, **publishes**) the `.vsix` automatically — no local
> `vsce package`, no manual upload. The packaged extension lands in the project's **Releases** +
> **Generic Package Registry**, privately, ready for the bootstrap installer to fetch. Scheduled for
> the hardening phase; documented now so it isn't lost.

---

## 1. What the pipeline produces
- **On every push / MR:** validate + typecheck + headless tests + a packaged `.vsix` as a
  **build artifact** (downloadable from the job, not published).
- **On a version tag (`v*`):** all of the above **plus** publish the `.vsix` to the **Generic Package
  Registry** and create a **GitLab Release** linking it. This is the privately-installable artifact.
- **(Optional) content validation:** validate the `.kiro/` agents/skills/manifest shape (frontmatter,
  manifest references resolve) — the CI idea seeded in doc 04.

---

## 2. Topology (stages → jobs)

```
validate  →  test  →  package  →  publish
 │            │         │           └─ publish_release   (tags v* only)
 │            │         └─ package_vsix                  (all pushes/MRs; artifact)
 │            └─ unit_tests        (headless node tests)
 └─ typecheck / lint / schema / (optional) content_validate
```

| Stage | Job | Runs on | Purpose |
|---|---|---|---|
| validate | `typecheck` | push/MR | `tsc --noEmit` on `installer/`. |
| validate | `schema_lint` | push/MR | ajv-validate manifest/environments/secrets/lockfile fixtures + the repo manifest. |
| validate | `content_validate` (optional) | push/MR | SKILL.md frontmatter valid; manifest references resolve; agent `.json` parses. |
| test | `unit_tests` | push/MR | run `installer/test/*` headless (the smoke + core tests). |
| package | `package_vsix` | push/MR | `vsce package` → `solutions-copilot.vsix` artifact. |
| publish | `publish_release` | **tags `v*`** | upload `.vsix` to Generic Package Registry + create a Release linking it. |

---

## 3. Runner & image
- **Image:** `node:20` (matches the dev toolchain; vsce + esbuild are pure Node — **no Docker-in-Docker
  needed**; the MCP images are built elsewhere).
- **Runner:** any shared/group runner on `gitlab.appian-stratus.com` that can run Linux Docker
  executors. Confirm a runner is available to the project (prerequisite).
- **`release-cli`:** the `publish_release` job uses the `registry.gitlab.com/gitlab-org/release-cli`
  image (or `release-cli` preinstalled) to create the Release.

---

## 4. The `.gitlab-ci.yml` (place at repo root)

```yaml
stages: [validate, test, package, publish]

variables:
  INSTALLER_DIR: installer
  VSIX_NAME: solutions-copilot.vsix
  # Package Registry coordinates (per tag)
  PKG_NAME: solutions-copilot

default:
  image: node:20
  cache:
    key:
      files: [installer/package-lock.json]
    paths: [installer/node_modules/]
  before_script:
    - cd "$INSTALLER_DIR"
    - npm ci --no-audit --no-fund

# ---------- validate ----------
typecheck:
  stage: validate
  script:
    - npx tsc --noEmit -p ./
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH'
    - if: '$CI_COMMIT_TAG'

schema_lint:
  stage: validate
  script:
    - node scripts/validate-schemas.js   # ajv-validates fixtures + repo manifest
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH'
    - if: '$CI_COMMIT_TAG'

# ---------- test ----------
unit_tests:
  stage: test
  script:
    - npm run compile
    - node test/smoke.js
    - for f in test/*.test.js; do node "$f"; done
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH'
    - if: '$CI_COMMIT_TAG'

# ---------- package ----------
package_vsix:
  stage: package
  script:
    # On a tag, force package.json version to match the tag (strip leading v).
    - |
      if [ -n "$CI_COMMIT_TAG" ]; then
        VER="${CI_COMMIT_TAG#v}"
        npm version "$VER" --no-git-tag-version --allow-same-version
      fi
    - npm run compile
    - npx --yes @vscode/vsce package --no-dependencies --allow-missing-repository -o "$VSIX_NAME"
  artifacts:
    paths: [installer/$VSIX_NAME]
    expire_in: 30 days
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH'
    - if: '$CI_COMMIT_TAG'

# ---------- publish (tags only) ----------
upload_package:
  stage: publish
  needs: [package_vsix]
  script:
    - |
      curl --fail --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
        --upload-file "$VSIX_NAME" \
        "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PKG_NAME}/${CI_COMMIT_TAG}/${PKG_NAME}-${CI_COMMIT_TAG}.vsix"
  rules:
    - if: '$CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+/'

publish_release:
  stage: publish
  needs: [upload_package]
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  before_script: []          # override the node before_script
  script:
    - |
      release-cli create \
        --name "Solutions Copilot ${CI_COMMIT_TAG}" \
        --tag-name "${CI_COMMIT_TAG}" \
        --description "Automated release of the Solutions Copilot installer ${CI_COMMIT_TAG}." \
        --assets-link "{\"name\":\"${PKG_NAME}-${CI_COMMIT_TAG}.vsix\",\"url\":\"${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/${PKG_NAME}/${CI_COMMIT_TAG}/${PKG_NAME}-${CI_COMMIT_TAG}.vsix\",\"link_type\":\"package\"}"
  rules:
    - if: '$CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+/'
```

Notes:
- `npm ci` requires `installer/package-lock.json` committed (add it).
- If `installer/**`-only pipelines are desired, add `changes: [installer/**/*]` to the branch rules.
- The optional `content_validate` job lives at repo root (different `before_script`); add when the
  content-validation script exists.

---

## 5. Versioning & tagging strategy
- **Source of truth = the git tag** `vMAJOR.MINOR.PATCH`. `package_vsix` rewrites `package.json`
  version from the tag so the `.vsix` version always matches the Release.
- Branch/MR builds keep the in-repo `package.json` version (pre-release artifact only).
- Tag from `main` after CI is green: `git tag v0.3.0 && git push origin v0.3.0` → publish runs.
- Consider **protected tags** (`v*`) so only maintainers can trigger a publish.

---

## 6. Publishing targets & resulting URLs
- **Generic Package Registry:** `…/api/v4/projects/<id>/packages/generic/solutions-copilot/<tag>/solutions-copilot-<tag>.vsix`
- **Release:** Project → Deployments/Releases → "Solutions Copilot <tag>" with the `.vsix` asset link.
- Both are private to project members — **no public marketplace / Open VSX**.

---

## 7. Auth & permissions
- **`CI_JOB_TOKEN`** (auto-provided) authorizes uploading to the project's own Package Registry and
  creating Releases — no PAT needed.
- Ensure the project's CI/CD setting **"Limit access to this project" / job-token allowlist** permits
  the package upload (same project is fine by default).
- **Protected tags** `v*` + maintainer-only push to restrict who can cut a release.
- No secrets are needed in CI for build/package; nothing in the pipeline handles end-user secrets.

---

## 8. Bootstrap install (consumes the published `.vsix`)
A one-liner for users (ships in the installer README), using their GitLab token to fetch the latest
release asset and sideload it into Kiro:
```bash
# pseudo: resolve latest v* tag → download the .vsix from the Generic Package Registry → install
TOKEN=<glpat>; PROJ=<id>
TAG=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" "https://gitlab.appian-stratus.com/api/v4/projects/$PROJ/repository/tags?per_page=1" | sed -n 's/.*"name":"\(v[^"]*\)".*/\1/p')
curl -s --header "PRIVATE-TOKEN: $TOKEN" -o sc.vsix \
  "https://gitlab.appian-stratus.com/api/v4/projects/$PROJ/packages/generic/solutions-copilot/$TAG/solutions-copilot-$TAG.vsix"
kiro --install-extension sc.vsix --force
```
> ⚠️ **Reload after install.** A newly sideloaded `.vsix` only activates after a **window reload**
> (Cmd+Shift+P → "Developer: Reload Window", or quit & reopen). The previously-running extension host
> keeps executing until then — installing without reloading runs the *old* version (see doc 11 §6.6).

(The extension's own update-check reuses the same Releases/tags API to notify users of new versions.)

---

## 9. Quality gates / MR policy
- Mark `typecheck`, `schema_lint`, `unit_tests` as **required** for MR merge (project MR settings:
  "Pipelines must succeed").
- `package_vsix` on MRs gives reviewers a downloadable build to sideload-test before merge.

---

## 10. Prerequisites & sequencing
- **Prereqs:** a CI runner available to the project; `installer/package-lock.json` committed;
  `scripts/validate-schemas.js` and `installer/test/*.test.js` exist (land with doc 14 Phases B–E).
- **Sequencing:** implement in **doc 14 Phase F** (hardening). Stand up `validate`+`test`+`package`
  first (works even before publishing is wanted); add `publish_*` once the first tag is cut.

---

## 11. Future enhancements
- Cache the esbuild/ts build; split `installer/**` vs content pipelines via `changes:` rules.
- Auto-generate release notes from the manifest diff (added/changed roles & skills).
- Sign the `.vsix` (checksum published alongside) and record the digest in the release.
- A scheduled pipeline to rebuild against the latest content ref for smoke validation.
