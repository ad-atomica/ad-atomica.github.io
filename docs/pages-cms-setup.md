# Pages CMS setup checklist

The repository contains the Pages CMS schema and automation. Complete these repository and Cloudflare settings after `cms-preview` has been pushed.

## GitHub

1. Verify the Pages CMS GitHub App is installed for this repository only.
2. Rework the repository-wide `restrict all` ruleset so it does not block the Pages CMS App or GitHub Actions from updating `cms-preview`.
3. Keep the `main` ruleset PR-only, with one approval, squash merging, linear history, deletion protection, and non-fast-forward protection.
4. Do not require linear history on `cms-preview`; synchronization from `main` creates merge commits.
5. Set workflow permissions to **Read and write permissions** and enable **Allow GitHub Actions to create and approve pull requests**. Reviews are still required by the `main` ruleset.
6. Add the `site-checks` job as a required status check on `main` after its first successful run.
7. Test the **Request publication** Pages CMS action. It must reject every source branch except `cms-preview` and create a clean PR containing only CMS-managed paths.
8. After synchronization has been tested manually, create the repository variable `CMS_SYNC_ENABLED` with value `true`.

CMS-managed publication paths are:

```text
_data/home.yml
_data/site.yml
_people/
assets/uploads/
```

Changes to templates, workflows, `.pages.yml`, or other developer-owned files must use a normal development pull request.

## Cloudflare Pages preview

Create a Cloudflare Pages project connected to this repository without moving the production domain during the pilot.

- Production branch: `main`
- Preview branch: `cms-preview`
- Build command: `bundle exec jekyll build`
- Output directory: `_site`
- Ruby version: read from `.ruby-version`

Record the stable `cms-preview.<project>.pages.dev` alias and provide it to editors. Keep `adatomica.com` on the existing GitHub Pages deployment until the full edit-preview-publish cycle has succeeded.

## Acceptance test

Ask a nontechnical editor to update homepage copy and one biography, replace one headshot, preview the result, and request publication. Confirm that:

- Pages CMS cannot write to `main`;
- validation catches invalid profile data and images;
- the stable preview updates after a save;
- the publication PR contains only managed content;
- one approval and the required check are needed to merge;
- merging publishes GitHub Pages; and
- `main` synchronizes back into `cms-preview` without discarding newer draft content.
