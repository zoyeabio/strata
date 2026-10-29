---
title: "Privacy Policy"
description: "How the Strata example records consent, demonstrates advertising, and handles the optional contact form."
keywords: ["privacy", "cookies", "advertising", "rights", "legal"]
---

This is the policy for the Strata demonstration site. It documents the
features enabled in this example repository; a production publisher must
replace the example identity, contact details and vendors with its own.

## Who operates this example

Strata Studio maintains this demonstration. Questions about the example can
be sent to `hello@strata.example`. The `.example` address and the Portland
address shown elsewhere on the site are reserved demonstration data, not a
real business contact.

## What the site stores

The consent banner stores one value in the visitor's browser under
`strata-cookie-consent`: `granted` or `denied`. The value remembers the
choice until the visitor changes it or clears browser storage. It is not sent
to the site and is not used to identify the visitor.

The contact form demonstrates the theme's form contract by posting to
`/api/contact`. This repository does not provide that endpoint or retain form
submissions. A deployer that connects the form to a mailbox, worker or CRM
must describe that service, its purpose and retention period here.

The hosting provider may keep ordinary request logs containing an IP address,
browser information, request time, requested URL and referring page. This
repository does not select a host or control those logs; a production deployer
must identify its host and publish the applicable retention period.

## Advertising

One article contains a demonstration AdSense unit with a non-production
publisher ID. No Google advertising script is requested until the visitor
selects **Accept ads**. Selecting **Essential only** keeps the loader out of
the page and collapses the reserved ad space.

After consent, the browser may send the page URL and IP address to Google and
Google may read or set advertising identifiers from domains including
`google.com`, `doubleclick.net`, `googlesyndication.com` and
`googleadservices.com`. Google uses them for ad delivery, frequency control,
fraud prevention and reporting. This example does not load Google Analytics.

Google's controls are available in
[Google Ad Settings](https://adssettings.google.com) and
[My Activity](https://myactivity.google.com/).

## Changing the choice

Use **Change** in the banner to accept or decline again, or clear browser
storage. If advertising code has already loaded, declining removes the
reserved ad space and reloads the page once so the previous advertising
session does not continue on that visit.

## Sharing and retention

Without advertising consent, this repository sends no advertising data to
Google. With consent, Google processes the advertising request under its own
published policies. The local consent choice remains only in the browser
until it is changed or cleared. The repository itself keeps no visitor
database.

## Your choices

Visitors can decline advertising, withdraw a previous choice, clear stored
site data in the browser, and use Google's account controls. A production
publisher must also provide the controller identity, jurisdiction-specific
rights, regulator contact and any vendor or international-transfer details
that apply to its deployment.

## Children and changes

This technical demonstration is not directed at children and does not
knowingly collect information from them. This page changes whenever the
example's data flow changes. Last updated: 2026-10-29.
