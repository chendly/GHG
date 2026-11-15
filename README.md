# Gordo Hospitality Group (GHG) — Unified Ordering Website

**ONE site, ONE GitHub repo, ONE Supabase tenant.** The online customer ordering site and the new SAKO walk-in counter are **different screens of the same project**.

## Baseline / source provenance
The public GHG Netlify site `ghgaruba` currently publishes deployment `6adf6bbf9861a7ea3d5d1579` (October 26, 2026 at 15:03 UTC), a manual Netlify Drop. Its source was saved as `GHG_SAKO_v8_DAILY_ORDERING_READY_TO_DEPLOY_2026-10-26.zip` and the byte-identical `GHG_Daily_Ordering.zip`. This repo restores the published HTML and JPG assets from that immutable Netlify deployment; the original archive is retained separately as backup.

## Screens
| Route | Purpose |
| --- | --- |
| `/` | Original live customer online ordering — **do not redesign** |
| `/admin/` | Original GHG admin/management dashboard |
| `/kitchen/` | Original kitchen operations |
| `/front/` | Original front of house |
| `/driver/` | Original driver operations |
| `/counter/` | New staff-only quick walk-in ordering and optional loyalty |
| `/admin/` → Customer Loyalty | Manager-only searchable balances, paid orders, earned/used/available points, and redeemable AWG |

**Important:** The staff counter is not a different Netlify or Supabase project. `/counter/index.html` calls the already-deployed authenticated Supabase Edge API `ghg-quick-order`. It uses the same tenant `gordo-hospitality-group` and current menu, products, order history and payment ledger.

## Counter behavior
- Anonymous immediate walk-in order: simply tap items/options and record order. No mandatory name/email/phone.
- Optionally record customer name and phone. With consent, optionally email, look up earned points and redeem their available points when they consent at the counter.
- Points accrue at 1 point per eligible AWG paid. The **approved live redemption rate is 10 points = AWG 1 off**; customer reward redemption is enabled, with points reserved on order entry and finalized after actual payment. Cancellation or void releases the points.
- Orders start unpaid and must be paid through existing GHG till/payment processes, exactly as before.
- The online storefront and its existing customer checkout are preserved as-is. Staff and customer authentication remain on their respective original routes.

## Netlify
Connect the **existing `ghgaruba` project** to this GitHub repo *only after* the import completes and the root `index.html`, four staff pages, four JPG assets and `counter/index.html` are all present.
- Repo: `chendly/GHG`, branch: `main`
- Base directory: repository root
- Build command: *(leave blank)*
- Publish directory: `.` (repo root)
- No extra Netlify projects or new Supabase projects.
- Keep the current published Netlify deploy until the merged repo passes checks, and preserve the published deploy for rollback.

## GHG branding & routes
The existing site uses deep green `#24473F`, cream `#FFF8EF`, terracotta `#D87750` and sage `#DCE5DD`. Customer storefront branding and copy are not changed by this import.

## Repository visibility
This repository was created **PUBLIC**. Because the site includes internal operations screens and historical migration files, changing visibility to **PRIVATE** before inviting staff/connecting workflows is strongly recommended. No secrets or service-role keys should be committed.

## Operational notes
Original source and staff app were restored from the original deployed package and Moonlight OS, not reverse-designed. The server-side GHG loyalty and immediate walk-in backend already exists. Before using the counter with paying guests, sign in on a staff device, check live menu/options, test payment and verify ledger, points and source attribution.
