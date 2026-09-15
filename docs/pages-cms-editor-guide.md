# Editing the Ad Atomica website

Pages CMS lets the team update approved website content without editing HTML or code. During the pilot, it exposes contact and company details, navigation labels, search/social copy, and existing team profiles.

## Edit and preview

1. Sign in to Pages CMS using the invitation email.
2. Open `ad-atomica/ad-atomica.github.io`.
3. Select the `cms-preview` branch. Do not edit `main`.
4. Open **Site settings** or **People** and make the change.
5. Save. Each save creates a commit on `cms-preview` and starts the validation and preview builds.
6. Wait for the checks to pass, then inspect the stable Cloudflare preview URL supplied by the website maintainer. Check both a desktop and a phone-sized screen.

For headshots, use a square JPG, PNG, or WebP image between 240 and 1200 pixels wide and no larger than 500 KB. Add a concise image description, normally the person's name.

## Request publication

1. Finish all changes intended for the same release.
2. Select **Request publication** in Pages CMS.
3. Confirm the request. The website checks run again and a pull request is opened for review.
4. Send the pull-request link to the designated reviewer.
5. After approval and successful checks, a repository maintainer merges the pull request. GitHub Pages then publishes `main`.

A publication request includes all unpublished CMS changes currently on `cms-preview`. Coordinate with other editors before requesting publication.

## If something goes wrong

- **A save is rejected:** confirm that `cms-preview`, not `main`, is selected. If it still fails, send the error to the website maintainer; do not switch branches to work around it.
- **A check fails:** open the failed check for its message. Common causes are a missing required field, duplicated display order, invalid link, or an oversized/non-square image.
- **The preview is stale:** wait for the Cloudflare deployment to complete and reload the page. If the deployment failed, contact the website maintainer.
- **Incorrect content was published:** ask a maintainer to revert the publication pull request rather than editing production directly.

Profile creation, deletion, and renaming are disabled during the pilot. Ask a maintainer when the team structure changes.
