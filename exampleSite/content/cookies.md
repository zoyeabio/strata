---
title: "Cookies"
description: "The browser storage used by the Strata example and what can load after advertising consent."
keywords: ["cookies", "consent", "advertising", "legal"]
---

## What this example stores

The example records the consent banner choice in browser local storage. It
does not set an analytics cookie and does not load Google Analytics.

| Name | Purpose | Lifetime |
|---|---|---|
| `strata-cookie-consent` | Remembers `granted` or `denied` so the advertising gate can honour the choice | Until the visitor changes it or clears browser storage |

## Advertising storage

The banner asks before the demonstration AdSense loader is requested.
Selecting **Essential only** loads no advertising script. After **Accept
ads**, Google may use advertising cookies or similar identifiers for ad
delivery, frequency control, fraud prevention and reporting.

| Provider | Purpose | When it can load | Lifetime |
|---|---|---|---|
| Google advertising services | Deliver and measure ads, limit repetition and detect fraud | Only after **Accept ads** | Controlled by Google and the visitor's browser or Google account settings |

## How to withdraw

Use **Change** in the banner and select **Essential only**, or clear this
site's browser storage. If advertising code already loaded, the theme removes
the reserved ad space and reloads the current page once. Google's retained
account data can be managed in
[Google Ad Settings](https://adssettings.google.com) and
[My Activity](https://myactivity.google.com/).

The longer explanation is in the
[privacy policy](/privacy-policy/). A real deployment must replace these
example disclosures with the exact storage, vendors and retention periods it
uses.
