/**
 * Lighthouse CI for the example site.
 *
 * `npm run lighthouse` — runs after `npm run build`, scores the built site,
 * and fails the shell on a threshold breach. Local only: this repo ships no
 * workflow, so the check is one a developer runs before pushing.
 *
 * @lhci/cli is run through npx and pinned in package.json's script rather than
 * committed as a devDependency. It pulls ~320 packages and ~120MB for a check
 * that runs on a laptop once a week; keeping it out of the lockfile leaves the
 * build at the four Tailwind packages it actually needs.
 *
 * Two deliberate choices:
 *
 * - The server is bound to 127.0.0.1. The scores are local-network numbers
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
      startServerCommand: 'hugo server --port ' + port + ' --bind 127.0.0.1',
      startServerReadyPattern: 'Waiting for editing command',
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
        'no-document-write': ['error', {maxNumericValue: 0}],
        'no-console-errors': ['error', {maxNumericValue: 0}],
        'image-alt': ['error', {maxNumericValue: 0}],
        'color-contrast': ['error', {maxNumericValue: 0}],
        'tap-targets': ['warn', {maxNumericValue: 0}],
        'meta-description': ['error', {maxNumericValue: 0}],
        'document-title': ['error', {maxNumericValue: 0}],
        'heading-order': ['warn', {maxNumericValue: 0}],
        'link-name': ['warn', {maxNumericValue: 0}],
        'canonical': ['warn', {maxNumericValue: 0}],
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
