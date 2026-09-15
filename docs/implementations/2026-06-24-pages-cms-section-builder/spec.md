# Constrained Pages CMS section builder

Status: Approved
Date: 2026-06-24
Target branch: `cms-preview`

## Context

The first Pages CMS migration moved homepage content into structured files, but its schema mirrors the current HTML section-for-section. Editors can change copy but cannot add, remove, or reorder meaningful page sections.

The replacement should support bounded page composition without becoming a free-form page builder. Nontechnical editors should be able to restructure the homepage using a small library of developer-owned components while preserving accessibility, responsive behavior, visual consistency, and safe publishing.

## Goals

- Keep the hero first and the contact area last.
- Let editors add, remove, and reorder body sections.
- Offer a small set of approved section types rather than arbitrary HTML or rich text.
- Generate navigation from the composed body sections.
- Keep templates, CSS, anchors, rendering behavior, and CTA destinations constrained and validated.
- Preserve the existing homepage content and visual hierarchy during migration.
- Continue using Jekyll, Pages CMS, `_data`, `_people`, and the existing publication workflow.

## Non-goals

- Arbitrary HTML, Markdown, embeds, scripts, CSS, colours, spacing, or column definitions.
- Nested section builders or sections containing other sections.
- Arbitrary internal or external CTA destinations.
- A general-purpose multi-page site builder in this milestone.
- Editor control over the page shell, SEO templates, footer structure, or person-card markup.

## Page structure

`_data/home.yml` will have three top-level areas:

```yaml
hero:
  heading: Drug discovery reinvented.
  cta_label: Get in Touch

sections:
  - type: intro
    anchor: process
    navigation_label: Our Process
    theme: neutral
    # type-specific fields

contact:
  eyebrow: Contact
  heading: Get in Touch
  body: ...
  cta_label: Start a conversation
```

The template renders them in this order:

1. Fixed hero
2. Ordered `sections` block list
3. Fixed contact

The header, footer, page shell, contact identity, contact destination, and SEO rendering remain developer-owned.

## Common body-section contract

Every body section has:

- `type`: Pages CMS block discriminator; editor chooses from approved types.
- `anchor`: required, unique lowercase slug matching `^[a-z0-9]+(?:-[a-z0-9]+)*$` and limited to 50 characters.
- `navigation_label`: optional text limited to 24 characters.
- `theme`: one of `neutral` or `accent`.

The renderer maps `theme` to developer-owned CSS classes. Editors cannot enter class names or style values.

If `navigation_label` is present, the navigation renders a link to that section's `anchor`. Sections without a navigation label remain outside the primary navigation. Reordering sections therefore reorders their navigation entries automatically. At most five body sections may appear in navigation so the menu remains bounded; smaller viewports use a height-constrained scrolling menu.

CTA-capable sections expose only an optional CTA label. A rendered CTA always targets the fixed `#contact` section; no href field is exposed.

## Supported section types

### Intro

Purpose: introduce a topic with a strong editorial hierarchy.

Fields:

- optional eyebrow, maximum 24 characters
- required heading, maximum 80 characters
- optional lead, maximum 500 characters
- one to three required plain-text paragraphs, each maximum 700 characters

Rendering: split-copy intro component, responsive and independent of adjacent section types.

### Card grid

Purpose: explain processes, capabilities, partnership types, or other short grouped content.

Fields:

- optional eyebrow
- optional heading
- optional introduction, maximum 500 characters
- `numbered`: boolean
- two to four cards
- each card has a required title and plain-text body
- optional CTA label, always linked to `#contact`

The heading and introduction may both be omitted when the cards follow a separate intro section. The grid must be count-independent across two, three, or four cards.

### Statement

Purpose: display one prominent supporting or transitional message.

Fields:

- one or two required plain-text paragraphs

Rendering supplies emphasis through component typography and layout; inline markup is not editable.

### Video

Purpose: embed one approved YouTube video.

Fields:

- required heading
- optional introduction
- required 11-character YouTube video ID
- required accessible iframe title

The template constructs a `youtube-nocookie.com` URL. Editors cannot enter iframe markup or a general URL.

### People grid

Purpose: render team or advisory profiles from the existing `_people` collection.

Fields:

- required heading
- optional introduction
- `group`: `team` or `advisor`

The component renders published profiles in their configured order. At most one people section for each group is permitted.

## Initial section sequence

Existing content maps to the new model as follows:

1. `intro` — Our Process
2. `card-grid` — three numbered process cards
3. `statement` — closing process and internal-programmes copy
4. `video` — platform video
5. `card-grid` with `accent` theme — How We Work and two partnership cards
6. `people-grid` — team
7. `people-grid` — advisory

The hero and contact content remain in their fixed top-level objects.

## Rendering architecture

- `index.html` renders fixed hero/contact components and loops over `site.data.home.sections`.
- A single dispatcher include selects a template using the validated `type` discriminator.
- Section templates live under `_includes/sections/`:
  - `intro.html`
  - `card-grid.html`
  - `statement.html`
  - `video.html`
  - `people-grid.html`
- Every editable value is escaped before rendering.
- Includes own semantic elements, CSS classes, iframe attributes, CTA destinations, and collection queries.
- Unknown section types are rejected by validation and must not silently render.
- Navigation loops over the same ordered section data and appends the fixed contact CTA.

CSS must replace assumptions tied to the current section order or child count with component and theme classes. Card and people grids must remain usable at their allowed counts and responsive breakpoints.

## Pages CMS configuration

The `Homepage sections` file form will expose:

- fixed `hero` object
- a `sections` field using `type: block`
- a fixed `contact` object

The block list will:

- allow one to twelve body sections
- support add, remove, and reorder operations
- use `type` as `blockKey`
- provide the five approved block definitions
- use required `list.collapsible` configuration
- show section type, heading where available, and index in collapsed summaries
- constrain list sizes and field lengths to match repository validation

Site settings and people remain separate CMS entries. No template, stylesheet, workflow, or configuration source is exposed as content.

## Validation

`scripts/validate_content.rb` will validate:

- hero and contact fixed fields
- one to twelve body sections
- known section types only
- required fields and type-specific length limits
- unique, valid anchors
- navigation-label limits and at most five body navigation entries
- approved themes only
- two to four cards in each card grid
- one to three intro paragraphs
- one to two statement paragraphs
- valid YouTube IDs
- `team` or `advisor` people groups
- no duplicate people section for a group
- CTA labels without editable destinations

Existing site settings, profile, image, and display-order validation remains in place.

Negative tests must demonstrate rejection of duplicate anchors, unknown types, invalid list sizes, invalid video IDs, and duplicate people groups.

## Data flow

1. An editor modifies `_data/home.yml` through the Pages CMS block editor on `cms-preview`.
2. Pages CMS commits the structured YAML change.
3. Site checks validate the content model and build Jekyll.
4. Cloudflare renders the stable `cms-preview` deployment.
5. The editor reviews section order and responsive rendering.
6. Request publication snapshots `_data/home.yml` and other managed content into a clean PR.
7. Required checks and review gate the merge to `main`.

## Failure modes

- **Invalid or duplicate anchor:** validation fails with the section index and field.
- **Navigation label without usable section target:** validation fails before build.
- **Unsupported section type:** validation fails rather than dropping content.
- **Too many/few cards or paragraphs:** Pages CMS constrains the editor and repository validation provides a second gate.
- **Overlong content causes poor layout:** field limits reduce risk; desktop and mobile preview remain required editorial checks.
- **Video input is a full or malicious URL:** strict video-ID validation rejects it and the template owns the host URL.
- **Duplicate team/advisory section:** validation fails to prevent accidental repeated profile grids.
- **Section removal leaves stale navigation:** navigation is generated from the same section list, so the link disappears with the section.
- **CMS serializes an unexpected shape:** content validation fails with a path-specific error.

## Testing and acceptance

Automated proof:

- Pages CMS YAML parses and block-list configuration matches the documented schema.
- Ruby content validator passes valid migrated content.
- Negative validator fixtures fail for each structural invariant.
- Jekyll production build succeeds.
- HTML-Proofer succeeds.
- Actionlint succeeds.
- Generated copy matches the current homepage after migration.
- Generated HTML contains no unresolved Liquid or broken local images.

Browser proof at desktop and mobile widths:

- initial content retains its current order and visual hierarchy
- two-, three-, and four-card grids render without overflow
- neutral and accent themes render correctly
- navigation order follows section order
- removing a navigation-labelled section removes its navigation entry
- moving the video or people sections does not break layout

Editor acceptance:

1. Add a new card-grid section.
2. Reorder it above the video.
3. Add a navigation label and confirm the navigation updates.
4. Remove the statement section and confirm its content and navigation disappear.
5. Preview desktop and mobile output.
6. Request publication and confirm the PR contains only CMS-managed paths.

## Follow-on workflow

Create an implementation plan from this specification, then execute it on `cms-preview`. The work should migrate the data and renderer together, update CMS configuration and validation, generalize CSS where needed, and preserve the existing publication controls.
