-- News feed: reference content, public read, no client write (same
-- editorial-content pattern as `drugs` — managed via Studio/an admin tool,
-- not by pharmacies). Category values are a placeholder set agreed with
-- the product owner; renaming a value later needs
-- `alter type news_category rename value 'old' to 'new'`, which is cheap,
-- but adding/removing a value mid-flight needs care if rows already use it.
create type news_category as enum (
  'regulatory',
  'market_pricing',
  'company_news',
  'recalls_safety',
  'industry_events',
  'education'
);

create table news_articles (
  id uuid primary key default gen_random_uuid(),
  category news_category not null,
  title text not null,
  summary text not null,
  body text not null,
  cover_image_url text,
  source text,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index idx_news_articles_category_published on news_articles (category, published_at desc);

alter table news_articles enable row level security;

create policy "news_articles: public read" on news_articles for select using (true);

-- Idempotent seed so the News screen isn't empty on first run — same
-- `where not exists` pattern as 0003_seed_drugs.sql.
insert into news_articles (category, title, summary, body, source, published_at)
select v.category, v.title, v.summary, v.body, v.source, v.published_at
from (values
  ('regulatory'::news_category, 'EDA updates controlled-substance dispensing rules',
    'New guidance tightens documentation requirements for Schedule II medicines.',
    'The Egyptian Drug Authority has issued updated guidance on dispensing and transferring controlled substances between licensed pharmacies, effective next quarter. Pharmacies should review their compliance logging before the deadline.',
    'Egyptian Drug Authority', now() - interval '2 days'),
  ('market_pricing'::news_category, 'Import costs push generic antibiotic prices up 8%',
    'Currency pressure continues to affect wholesale pricing across common generics.',
    'Wholesale prices for several widely-used generic antibiotics rose an average of 8% this month, driven largely by import cost pressure. Pharmacies are advised to review outstanding listings for stale pricing.',
    'Pharma Exchange Market Desk', now() - interval '5 days'),
  ('company_news'::news_category, 'Pharma Exchange Egypt passes 500 verified pharmacies',
    'The network crosses a milestone as more licensed pharmacies join the marketplace.',
    'Pharma Exchange Egypt has onboarded its 500th KYC-verified pharmacy this month, expanding coverage across all governorates and improving near-expiry stock liquidity for the whole network.',
    'Pharma Exchange Egypt', now() - interval '7 days'),
  ('recalls_safety', 'Voluntary recall notice: check affected batch numbers',
    'A manufacturer has issued a voluntary recall for specific batches — verify your stock.',
    'A supplier has issued a voluntary recall covering a limited set of batch numbers due to a labeling defect. Pharmacies holding affected stock should not list it for exchange and should follow the manufacturer''s return process.',
    'Supplier Safety Bulletin', now() - interval '1 day'),
  ('industry_events', 'Cairo Pharma Expo registration now open',
    'This year''s expo focuses on supply-chain digitization and inventory sharing.',
    'Registration has opened for this year''s Cairo Pharma Expo, with a dedicated track on supply-chain digitization, near-expiry stock management, and B2B exchange platforms.',
    'Cairo Pharma Expo', now() - interval '10 days'),
  ('education', 'Best practices for near-expiry inventory rotation',
    'A short guide to reducing write-offs through earlier, more proactive listing.',
    'Listing near-expiry stock earlier — rather than waiting until the final weeks before expiry — meaningfully improves the odds of a successful exchange. This guide covers a simple rotation checklist any pharmacy can adopt.',
    'Pharma Exchange Learning Hub', now() - interval '14 days')
) as v(category, title, summary, body, source, published_at)
where not exists (select 1 from news_articles n where n.title = v.title);
