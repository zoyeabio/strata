/**
 * Lighthouse CI for the example site.
 *
 * `npm run lighthouse` — creates a production build, serves its public/
 * directory, scores that artifact, and fails the shell on a threshold breach.
 * Local only: this repo ships no
 * workflow, so the check is one a developer runs before pushing.
 *
 * @lhci/cli is run through npx and pinned in package.json's script rather than
 * committed as a devDependency. It pulls ~320 packages and ~120MB for a check
 * that runs on a laptop once a week; keeping it out of the lockfile leaves the
 * build at the four Tailwind packages it actually needs.
 *
 * Two deliberate choices:
 *
 * - The static server is bound to 127.0.0.1. The scores are local-network numbers
 *   and say nothing about your host's CDN, so they would be noise in CI.
 * - There is no PWA category, and no audit is skipped. The site is not a PWA
 *   and skipping an audit to hit a number is how a threshold stops meaning
 *   anything. Every audit that is reported is reported for real.
 *
 * Browser: chrome-launcher finds a system Chrome or Chromium. Install one
 * rather than adding puppeteer, which downloads its own ~150MB copy for a
 * check that runs on a laptop once a week.
 */
const port = 8891;

module.exports = {
  ci: {
    collect: {
      url: [`http://127.0.0.1:${port}/`],
      // Do not audit `hugo server`: the theme intentionally blocks crawlers
      // outside production, which turns Lighthouse SEO into a false failure.
      startServerCommand:
        'hugo --minify && python3 -u -m http.server ' +
        port +
        ' --bind 127.0.0.1 --directory public',
      startServerReadyPattern: 'Serving HTTP',
      numberOfRuns: 1,
      settings: {
        preset: 'desktop',
        onlyCategories: ['performance', 'accessibility', 'best-practices', 'seo'],
        skipAudits: [],
      },
    },
    assert: {
      assertions: {
        'categories:performance': ['warn', {minScore: 0.9}],
        'categories:accessibility': ['error', {minScore: 0.95}],
        'categories:best-practices': ['warn', {minScore: 0.9}],
        'categories:seo': ['error', {minScore: 0.9}],

        // Page weight is the number that actually moves for this theme.
        'total-byte-weight': ['warn', {maxNumericValue: 500 * 1024}],
        'largest-contentful-paint-element': ['warn'],
        'render-blocking-resources': ['warn', {maxNumericValue: 0}],
        'uses-long-cache-ttl': ['warn'],
        'uses-text-compression': ['warn'],
        'is-on-https': ['off'],

        // The head is deliberately closed, so these must stay clean.
        'no-document-write': ['error', {minScore: 1}],
        'errors-in-console': ['error', {minScore: 1}],
        'image-alt': ['error', {minScore: 1}],
        'color-contrast': ['error', {minScore: 1}],
        'link-in-text-block': ['error', {minScore: 1}],
        'meta-description': ['error', {minScore: 1}],
        'document-title': ['error', {minScore: 1}],
        'heading-order': ['warn', {minScore: 1}],
        'link-name': ['warn', {minScore: 1}],
        'canonical': ['warn', {minScore: 1}],
      },
      budget: [
        {
          path: '/*',
          resourceSizes: [
            {resourceType: 'total', budget: 500},
            {resourceType: 'script', budget: 50},
            {resourceType: 'stylesheet', budget: 120},
            {resourceType: 'image', budget: 250},
          ],
          requests: [
            {resourceType: 'third-party', budget: 0},
            {resourceType: 'total', budget: 40},
          ],
        },
      ],
    },
  },
};
