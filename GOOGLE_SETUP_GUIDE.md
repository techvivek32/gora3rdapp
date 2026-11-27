# Google setup — what to do after the SEO code goes live

Written for: the person who owns the business, not a developer. Nothing here
needs code. Where a step needs something from me, it says so.

---

## Step 0 — Deploy first (otherwise there is nothing to submit)

Everything below points Google at `https://gorataxi.com`. Right now the live
site is still the old 9-page version — the sitemap does not exist yet on
production. Submitting it before deploying just gets an error.

**Say the word and I'll deploy it** (snapshot first, as always). Until then,
Steps 1-6 can all be read but only Step 4 can be started.

---

## Step 1 — Google Search Console (the most important one)

This is free, and it is how you find out what Google actually thinks of the
site: which pages it indexed, which it refused and why, what people searched
before clicking.

### 1a. Open it

Go to **https://search.google.com/search-console** and sign in with the Google
account you want to own this. Use a business account you will not lose access
to — not a personal one you might stop using.

### 1b. Add the property — pick "Domain", not "URL prefix"

You will be offered two boxes:

| | Covers | Verify with |
|---|---|---|
| **Domain** ← use this | `gorataxi.com`, `www.`, every subdomain, http and https | one DNS record |
| URL prefix | only the exact address you type | HTML file, tag, Analytics… |

Type `gorataxi.com` in the **Domain** box and press Continue.

### 1c. Add the DNS record

Google will show you a TXT record like:

```
google-site-verification=AbCdEf1234...
```

Add it where your domain's DNS is managed — for this domain that is almost
certainly **Hostinger → Domains → gorataxi.com → DNS / Name servers**:

- **Type:** TXT
- **Name / Host:** `@` (meaning the domain itself)
- **Value:** the whole `google-site-verification=...` string
- **TTL:** leave the default

Save, wait 5-30 minutes (sometimes a few hours), then press **Verify** in
Search Console.

> If Domain verification will not work for any reason, there is a fallback: I
> have already wired an environment variable for the HTML-tag method, so you
> would just send me the code and it goes live without a code change. But try
> the DNS one first — it is better.

### 1d. Submit the sitemap

Once verified: **Sitemaps** in the left menu → type `sitemap.xml` → Submit.

The full address is `https://gorataxi.com/sitemap.xml` and it currently lists
**717 pages**.

Status should move to "Success" within a day. "Couldn't fetch" usually just
means you submitted before deploying.

### 1e. Push the important pages to the front of the queue

Google will crawl on its own, but you can ask for a few. Use the search bar at
the top of Search Console (**URL Inspection**), paste a URL, then click
**Request Indexing**.

Worth doing for about ten pages — more than that and the button starts
refusing:

```
https://gorataxi.com/
https://gorataxi.com/taxi/jodhpur
https://gorataxi.com/taxi/jaipur
https://gorataxi.com/cab-service/rajasthan
https://gorataxi.com/cabs/jodhpur-to-jaipur
https://gorataxi.com/cabs/jaipur-to-jodhpur
https://gorataxi.com/cabs/jodhpur-to-udaipur
https://gorataxi.com/cabs/ahmedabad-to-mumbai
https://gorataxi.com/cabs/delhi-to-jaipur
https://gorataxi.com/pool
```

### 1f. What to check later, and when

| When | Where | What you are looking for |
|---|---|---|
| After 3-7 days | Pages (Indexing) | pages moving from "Discovered" to "Indexed" |
| After 2-4 weeks | Performance | first impressions — which searches show your site |
| Monthly | Pages → "Why pages aren't indexed" | reasons; send them to me, most are fixable |

**Do not panic if only a fraction is indexed.** Google indexes a new site
gradually, and it will never index all 77,006 route pages — nor should it. A
few hundred good ones earning clicks is the goal.

---

## Step 2 — Google Business Profile (for the map, and for local searches)

For a cab company this is often worth **more than the website**. When someone
searches "cab service near me" or "taxi in Jodhpur", the map box at the top
comes from here, not from your site.

### 2a. Create it

Go to **https://business.google.com** → Manage now → add your business.

### 2b. What to enter

| Field | What to put |
|---|---|
| Business name | **Gora Taxi** (the brand people search, not the legal name) |
| Primary category | **Taxi service** |
| Extra categories | Car rental agency, Airport shuttle service, Chauffeur service |
| Address | 132, Nayak Bhawan, Haripura Vyas Colony, Tempo Stand Airforce, Jodhpur, Rajasthan 342011 |
| Service areas | the cities you actually serve — Jodhpur, Jaipur, Udaipur, Kota, Bhilwara, Ahmedabad, Surat, Mumbai, Pune, Delhi |
| Phone | your support number |
| Website | `https://gorataxi.com` |

If you do not want the office address shown publicly, choose **"I deliver goods
and services to my customers"** — then only the service areas show, not the
street address. For a cab company that is usually the right choice.

### 2c. Verification

Google will ask for proof — usually a **video call or recorded video** now,
sometimes a postcard by post. The video wants to show your signage, the area
around the office, and you using something that proves it is your business.
Keep the GSTIN handy (`08AAMCG5008P1Z3`).

This step can take a few days to a couple of weeks. It is the slowest part, so
**start it early** — you can do it before the site deploys.

### 2d. After it is live

- **Photos.** At least 10 — cars inside and out, drivers, office. Listings with
  photos get far more clicks than those without.
- **Hours.** If you run 24×7, say so.
- **Services.** Add "Outstation cab", "One way drop", "Round trip", "Local
  hourly rental", "Airport transfer".
- **Reviews — this is the big one.** Ask every happy customer. Google's
  ranking in the map box leans heavily on review count and recency. A WhatsApp
  message with your review link after a completed trip works better than
  anything else. **Never buy reviews** — Google detects it and suspends the
  listing.
- **Posts.** A short update every week or two keeps the listing active.

---

## Step 3 — Bing Webmaster Tools (ten minutes, do it anyway)

Small traffic, but it costs almost nothing: **https://www.bing.com/webmasters**
→ sign in → **Import from Google Search Console**. It copies the verification
and the sitemap across in one click.

---

## Step 4 — Google Analytics 4 (optional, but you will want it)

**https://analytics.google.com** → create a property → it gives you a
measurement ID like `G-XXXXXXXXXX`.

Search Console tells you what happened *before* the click; Analytics tells you
what happened *after* — which pages lead to bookings and which do not. Send me
the ID and I will wire it in.

---

## What NOT to do

- **Do not buy backlinks or "SEO packages" that promise rank #1.** They work by
  spamming, Google catches it, and the penalty lands on your domain. Recovering
  takes longer than ranking honestly would have.
- **Do not buy reviews.** Fastest way to get the map listing suspended.
- **Do not stuff city names into page text.** The pages already carry real
  distances and fares; that is what makes them rank.
- **Do not keep resubmitting the sitemap.** Once is enough; Google rechecks it.

---

## Honest timeline

| When | What realistically happens |
|---|---|
| Days 1-7 | Google discovers the site, starts indexing the main pages |
| Weeks 2-4 | Route and city pages begin appearing; first impressions in Search Console |
| Months 2-3 | Long-tail searches ("jodhpur to udaipur cab") start bringing real clicks |
| Months 4-6+ | Competitive terms ("rajasthan cab service") move — if reviews and backlinks have grown |

Nobody can promise #1, and the terms with the most searches are the slowest.
What the code did was make the site *eligible*. Steps 1 and 2 above are what
make it *visible*, and they are yours to do — not code.

---

## Quick checklist

- [ ] Deploy the SEO work to production *(me — say the word)*
- [ ] Search Console → Domain property → DNS TXT → Verify
- [ ] Search Console → Sitemaps → `sitemap.xml`
- [ ] Request indexing for the 10 URLs above
- [ ] Google Business Profile → create → verify → photos, hours, services
- [ ] Start asking customers for reviews
- [ ] Bing Webmaster Tools → import from Google
- [ ] Fix Kota's state in the admin panel (`Raj` → `Rajasthan`)
- [ ] Mark the cities you really operate in as served in the admin panel
