-- Extensions
create extension if not exists "pgcrypto";

-- Roles
create type user_role as enum ('admin', 'partner', 'customer');

-- profiles extends auth.users (1:1)
create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    role user_role not null default 'customer',
    full_name text,
    phone text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

-- Auto-create a profile row when a new auth user signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create index profiles_role_idx on public.profiles(role);
-- Services (catalog entity, not hardcoded)
create table public.services (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,
    icon text,
    active boolean not null default true,
    sort_order int not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

create table public.service_translations (
    service_id uuid not null references public.services(id) on delete cascade,
    locale text not null,
    name text not null,
    short_description text,
    seo_title text,
    seo_description text,
    h1 text,
    content text,
    primary key (service_id, locale)
  );

-- ServiceOption: calculator configuration per service, DB-driven (not hardcoded forms)
create type service_option_type as enum ('select', 'multiselect', 'number', 'boolean');

create table public.service_options (
    id uuid primary key default gen_random_uuid(),
    service_id uuid not null references public.services(id) on delete cascade,
    key text not null,
    type service_option_type not null,
    required boolean not null default false,
    sort_order int not null default 0,
    step int not null default 2 check (step between 1 and 8),
    config jsonb not null default '{}'::jsonb,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (service_id, key)
  );

create index service_translations_locale_idx on public.service_translations(locale);
create index service_options_service_idx on public.service_options(service_id) where active;
create table public.cities (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,
    latitude numeric(9,6),
    longitude numeric(9,6),
    active boolean not null default true,
    sort_order int not null default 0,
    created_at timestamptz not null default now()
  );

create table public.city_translations (
    city_id uuid not null references public.cities(id) on delete cascade,
    locale text not null,
    name text not null,
    seo_title text,
    seo_description text,
    h1 text,
    content text,
    primary key (city_id, locale)
  );

create table public.districts (
    id uuid primary key default gen_random_uuid(),
    city_id uuid not null references public.cities(id) on delete cascade,
    slug text not null,
    active boolean not null default true,
    sort_order int not null default 0,
    created_at timestamptz not null default now(),
    unique (city_id, slug)
  );

create table public.district_translations (
    district_id uuid not null references public.districts(id) on delete cascade,
    locale text not null,
    name text not null,
    seo_title text,
    seo_description text,
    h1 text,
    content text,
    primary key (district_id, locale)
  );

create index districts_city_idx on public.districts(city_id);
create type pricing_rule_type as enum ('fixed', 'per_unit', 'multiplier', 'addon');

-- PricingRule: price is config-driven, calculated server-side only (never trust client price).
create table public.pricing_rules (
    id uuid primary key default gen_random_uuid(),
    service_id uuid not null references public.services(id) on delete cascade,
    match_conditions jsonb not null default '{}'::jsonb,
    price_type pricing_rule_type not null,
    amount numeric(10,2) not null check (amount >= 0),
    currency text not null default 'CZK',
    priority int not null default 0,
    active boolean not null default true,
    valid_from date,
    valid_to date,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

create index pricing_rules_service_idx on public.pricing_rules(service_id) where active;
create table public.partners (
    id uuid primary key default gen_random_uuid(),
    profile_id uuid references public.profiles(id) on delete set null,
    name text not null,
    phone text,
    email text,
    verified boolean not null default false,
    active boolean not null default true,
    rating numeric(3,2) check (rating between 0 and 5),
    completed_orders int not null default 0 check (completed_orders >= 0),
    avg_response_minutes int check (avg_response_minutes >= 0),
    bio text,
    photo_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

create table public.partner_services (
    partner_id uuid not null references public.partners(id) on delete cascade,
    service_id uuid not null references public.services(id) on delete cascade,
    primary key (partner_id, service_id)
  );

create table public.partner_cities (
    partner_id uuid not null references public.partners(id) on delete cascade,
    city_id uuid not null references public.cities(id) on delete cascade,
    primary key (partner_id, city_id)
  );

create table public.partner_districts (
    partner_id uuid not null references public.partners(id) on delete cascade,
    district_id uuid not null references public.districts(id) on delete cascade,
    primary key (partner_id, district_id)
  );

create index partners_verified_active_idx on public.partners(verified, active);

create table public.customers (
    id uuid primary key default gen_random_uuid(),
    profile_id uuid references public.profiles(id) on delete set null,
    name text,
    phone text,
    email text,
    created_at timestamptz not null default now()
  );
create type lead_status as enum ('NEW', 'TRANSFERRED', 'ACCEPTED', 'REJECTED', 'COMPLETED', 'SALE');
create type matching_status as enum ('pending', 'matched', 'no_partner_available');
create type assignment_status as enum ('NEW', 'OFFERED', 'ACCEPTED', 'REJECTED', 'COMPLETED');

create table public.leads (
    id uuid primary key default gen_random_uuid(),
    customer_id uuid references public.customers(id) on delete set null,
    service_id uuid not null references public.services(id),
    city_id uuid not null references public.cities(id),
    district_id uuid references public.districts(id),
    address text,
    object_params jsonb not null default '{}'::jsonb,
    estimated_price_min numeric(10,2),
    estimated_price_max numeric(10,2),
    preferred_date date,
    preferred_time text,
    comment text,
    photo_urls text[] not null default '{}',
    status lead_status not null default 'NEW',
    matching_status matching_status not null default 'pending',
    source text,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    utm_term text,
    utm_content text,
    landing_page text,
    referrer text,
    locale text not null default 'cs',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

create index leads_status_idx on public.leads(status);
create index leads_matching_status_idx on public.leads(matching_status);
create index leads_city_idx on public.leads(city_id);
create index leads_service_idx on public.leads(service_id);
create index leads_created_at_idx on public.leads(created_at desc);

create table public.assignments (
    id uuid primary key default gen_random_uuid(),
    lead_id uuid not null references public.leads(id) on delete cascade,
    partner_id uuid not null references public.partners(id),
    status assignment_status not null default 'NEW',
    score numeric(6,2),
    offered_at timestamptz,
    responded_at timestamptz,
    completed_at timestamptz,
    notes text,
    created_at timestamptz not null default now()
  );

create index assignments_lead_idx on public.assignments(lead_id);
create index assignments_partner_idx on public.assignments(partner_id);
create index assignments_status_idx on public.assignments(status);

create table public.orders (
    id uuid primary key default gen_random_uuid(),
    lead_id uuid not null unique references public.leads(id),
    assignment_id uuid references public.assignments(id),
    final_price numeric(10,2),
    completed_at timestamptz,
    created_at timestamptz not null default now()
  );

create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id) on delete cascade,
    label text not null,
    quantity numeric(10,2) not null default 1,
    unit_price numeric(10,2) not null,
    total_price numeric(10,2) not null
  );

create index order_items_order_idx on public.order_items(order_id);
-- Audit trail for CRM "view history" requirement + GDPR audit trail.
create table public.lead_status_history (
    id uuid primary key default gen_random_uuid(),
    lead_id uuid not null references public.leads(id) on delete cascade,
    from_status lead_status,
    to_status lead_status not null,
    changed_by uuid references public.profiles(id),
    note text,
    created_at timestamptz not null default now()
  );

create table public.assignment_status_history (
    id uuid primary key default gen_random_uuid(),
    assignment_id uuid not null references public.assignments(id) on delete cascade,
    from_status assignment_status,
    to_status assignment_status not null,
    changed_by uuid references public.profiles(id),
    note text,
    created_at timestamptz not null default now()
  );

create index lead_status_history_lead_idx on public.lead_status_history(lead_id);
create index assignment_status_history_assignment_idx on public.assignment_status_history(assignment_id);
create table public.reviews (
    id uuid primary key default gen_random_uuid(),
    order_id uuid references public.orders(id) on delete set null,
    partner_id uuid references public.partners(id) on delete set null,
    customer_id uuid references public.customers(id) on delete set null,
    rating int not null check (rating between 1 and 5),
    text text,
    published boolean not null default false,
    created_at timestamptz not null default now()
  );

create index reviews_published_idx on public.reviews(published);

create table public.cases (
    id uuid primary key default gen_random_uuid(),
    service_id uuid not null references public.services(id),
    city_id uuid not null references public.cities(id),
    district_id uuid references public.districts(id),
    partner_id uuid references public.partners(id) on delete set null,
    slug text not null unique,
    before_photo_urls text[] not null default '{}',
    after_photo_urls text[] not null default '{}',
    published boolean not null default false,
    created_at timestamptz not null default now()
  );

create table public.case_translations (
    case_id uuid not null references public.cases(id) on delete cascade,
    locale text not null,
    title text not null,
    description text,
    content text,
    seo_title text,
    seo_description text,
    primary key (case_id, locale)
  );

create index cases_published_idx on public.cases(published);
create index cases_district_idx on public.cases(district_id);

create table public.articles (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,
    author_id uuid references public.profiles(id) on delete set null,
    category text,
    featured_image text,
    related_service_ids uuid[] not null default '{}',
    related_city_ids uuid[] not null default '{}',
    published boolean not null default false,
    published_at timestamptz,
    updated_at timestamptz not null default now()
  );

create table public.article_translations (
    article_id uuid not null references public.articles(id) on delete cascade,
    locale text not null,
    title text not null,
    meta_title text,
    meta_description text,
    h1 text,
    content text,
    primary key (article_id, locale)
  );

create index articles_published_idx on public.articles(published);

create table public.faqs (
    id uuid primary key default gen_random_uuid(),
    category text,
    service_id uuid references public.services(id) on delete set null,
    sort_order int not null default 0,
    published boolean not null default true
  );

create table public.faq_translations (
    faq_id uuid not null references public.faqs(id) on delete cascade,
    locale text not null,
    question text not null,
    answer text not null,
    primary key (faq_id, locale)
  );
create type page_variant_type as enum ('service', 'city', 'city_service', 'district', 'district_service');

-- Controls SEO publication (section 5 of the brief): a page renders/indexes
-- only if a matching row exists here with is_published = true.
create table public.page_variants (
    id uuid primary key default gen_random_uuid(),
    page_type page_variant_type not null,
    service_id uuid references public.services(id) on delete cascade,
    city_id uuid references public.cities(id) on delete cascade,
    district_id uuid references public.districts(id) on delete cascade,
    locale text not null,
    is_published boolean not null default false,
    has_unique_content boolean not null default false,
    published_at timestamptz,
    updated_at timestamptz not null default now(),
    unique (page_type, service_id, city_id, district_id, locale)
  );

create index page_variants_published_idx on public.page_variants(is_published);
create type platform_mode as enum ('bootstrap', 'marketplace');
create type settings_scope as enum ('global', 'city');

create table public.platform_settings (
    id uuid primary key default gen_random_uuid(),
    scope settings_scope not null default 'global',
    city_id uuid references public.cities(id) on delete cascade,
    platform_mode platform_mode not null default 'bootstrap',
    min_verified_partners int not null default 2 check (min_verified_partners >= 0),
    matching_weights jsonb not null default '{
      "location": 30, "service": 20, "availability": 20,
      "rating": 15, "completedOrders": 10, "responseTime": 5
    }'::jsonb,
    assignment_timeout_hours int not null default 24 check (assignment_timeout_hours > 0),
    updated_at timestamptz not null default now(),
    unique (scope, city_id)
  );

create table public.feature_flags (
    id uuid primary key default gen_random_uuid(),
    key text not null unique,
    enabled boolean not null default false,
    rollout_percentage int not null default 100 check (rollout_percentage between 0 and 100),
    config jsonb,
    updated_at timestamptz not null default now()
  );
create type notification_channel as enum ('email', 'telegram', 'sms', 'whatsapp');
create type notification_recipient_type as enum ('customer', 'partner', 'admin');
create type notification_status as enum ('pending', 'sent', 'failed');

create table public.notifications (
    id uuid primary key default gen_random_uuid(),
    type text not null,
    channel notification_channel not null,
    recipient_type notification_recipient_type not null,
    recipient_ref text,
    payload jsonb not null default '{}'::jsonb,
    status notification_status not null default 'pending',
    related_lead_id uuid references public.leads(id) on delete set null,
    related_assignment_id uuid references public.assignments(id) on delete set null,
    error text,
    created_at timestamptz not null default now(),
    sent_at timestamptz
  );

create index notifications_status_idx on public.notifications(status);

create table public.analytics_events (
    id uuid primary key default gen_random_uuid(),
    event_name text not null,
    session_id text,
    lead_id uuid references public.leads(id) on delete set null,
    payload jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
  );

create index analytics_events_name_idx on public.analytics_events(event_name);
create index analytics_events_created_idx on public.analytics_events(created_at desc);
-- ============================================================================
-- RLS strategy: anon/authenticated can only READ published/allowed content.
-- leads/assignments/orders/PII/notifications/analytics are NEVER exposed to
-- anon/authenticated directly - writes go through Server Actions using the
-- service-role client. pricing_rules are never exposed to anon: price is
-- always computed server-side (calculateEstimate) using the service-role
-- client.
-- ============================================================================

create function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    );
$$;

alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.partners enable row level security;
alter table public.partner_services enable row level security;
alter table public.partner_cities enable row level security;
alter table public.partner_districts enable row level security;
alter table public.services enable row level security;
alter table public.service_translations enable row level security;
alter table public.service_options enable row level security;
alter table public.pricing_rules enable row level security;
alter table public.cities enable row level security;
alter table public.city_translations enable row level security;
alter table public.districts enable row level security;
alter table public.district_translations enable row level security;
alter table public.page_variants enable row level security;
alter table public.leads enable row level security;
alter table public.assignments enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.lead_status_history enable row level security;
alter table public.assignment_status_history enable row level security;
alter table public.reviews enable row level security;
alter table public.cases enable row level security;
alter table public.case_translations enable row level security;
alter table public.articles enable row level security;
alter table public.article_translations enable row level security;
alter table public.faqs enable row level security;
alter table public.faq_translations enable row level security;
alter table public.notifications enable row level security;
alter table public.analytics_events enable row level security;
alter table public.platform_settings enable row level security;
alter table public.feature_flags enable row level security;

create policy "public read active services" on public.services
  for select using (active = true);
create policy "public read service translations" on public.service_translations
  for select using (exists (select 1 from public.services s where s.id = service_id and s.active));
create policy "public read active service options" on public.service_options
  for select using (active = true);
create policy "public read active cities" on public.cities
  for select using (active = true);
create policy "public read city translations" on public.city_translations
  for select using (exists (select 1 from public.cities c where c.id = city_id and c.active));
create policy "public read active districts" on public.districts
  for select using (active = true);
create policy "public read district translations" on public.district_translations
  for select using (exists (select 1 from public.districts d where d.id = district_id and d.active));

create policy "public read published page_variants" on public.page_variants
  for select using (is_published = true);
create policy "public read published reviews" on public.reviews
  for select using (published = true);
create policy "public read published cases" on public.cases
  for select using (published = true);
create policy "public read published case translations" on public.case_translations
  for select using (exists (select 1 from public.cases c where c.id = case_id and c.published));
create policy "public read published articles" on public.articles
  for select using (published = true);
create policy "public read published article translations" on public.article_translations
  for select using (exists (select 1 from public.articles a where a.id = article_id and a.published));
create policy "public read published faqs" on public.faqs
  for select using (published = true);
create policy "public read published faq translations" on public.faq_translations
  for select using (exists (select 1 from public.faqs f where f.id = faq_id and f.published));

create policy "users read own profile" on public.profiles
  for select using (auth.uid() = id);
create policy "users update own profile" on public.profiles
  for update using (auth.uid() = id);
create policy "users read own customer row" on public.customers
  for select using (auth.uid() = profile_id);
create policy "admin all profiles" on public.profiles for all using (is_admin()) with check (is_admin());
create policy "admin all customers" on public.customers for all using (is_admin()) with check (is_admin());
create policy "admin all partners" on public.partners for all using (is_admin()) with check (is_admin());
create policy "admin all partner_services" on public.partner_services for all using (is_admin()) with check (is_admin());
create policy "admin all partner_cities" on public.partner_cities for all using (is_admin()) with check (is_admin());
create policy "admin all partner_districts" on public.partner_districts for all using (is_admin()) with check (is_admin());
create policy "admin all services" on public.services for all using (is_admin()) with check (is_admin());
create policy "admin all service_translations" on public.service_translations for all using (is_admin()) with check (is_admin());
create policy "admin all service_options" on public.service_options for all using (is_admin()) with check (is_admin());
create policy "admin all pricing_rules" on public.pricing_rules for all using (is_admin()) with check (is_admin());
create policy "admin all cities" on public.cities for all using (is_admin()) with check (is_admin());
create policy "admin all city_translations" on public.city_translations for all using (is_admin()) with check (is_admin());
create policy "admin all districts" on public.districts for all using (is_admin()) with check (is_admin());
create policy "admin all district_translations" on public.district_translations for all using (is_admin()) with check (is_admin());
create policy "admin all page_variants" on public.page_variants for all using (is_admin()) with check (is_admin());
create policy "admin all leads" on public.leads for all using (is_admin()) with check (is_admin());
create policy "admin all assignments" on public.assignments for all using (is_admin()) with check (is_admin());
create policy "admin all orders" on public.orders for all using (is_admin()) with check (is_admin());
create policy "admin all order_items" on public.order_items for all using (is_admin()) with check (is_admin());
create policy "admin all lead_status_history" on public.lead_status_history for all using (is_admin()) with check (is_admin());
create policy "admin all assignment_status_history" on public.assignment_status_history for all using (is_admin()) with check (is_admin());
create policy "admin all reviews" on public.reviews for all using (is_admin()) with check (is_admin());
create policy "admin all cases" on public.cases for all using (is_admin()) with check (is_admin());
create policy "admin all case_translations" on public.case_translations for all using (is_admin()) with check (is_admin());
create policy "admin all articles" on public.articles for all using (is_admin()) with check (is_admin());
create policy "admin all article_translations" on public.article_translations for all using (is_admin()) with check (is_admin());
create policy "admin all faqs" on public.faqs for all using (is_admin()) with check (is_admin());
create policy "admin all faq_translations" on public.faq_translations for all using (is_admin()) with check (is_admin());
create policy "admin all notifications" on public.notifications for all using (is_admin()) with check (is_admin());
create policy "admin all analytics_events" on public.analytics_events for all using (is_admin()) with check (is_admin());
create policy "admin all platform_settings" on public.platform_settings for all using (is_admin()) with check (is_admin());
create policy "admin all feature_flags" on public.feature_flags for all using (is_admin()) with check (is_admin());
-- No policy = default deny. anon/authenticated have NO access to:
-- pricing_rules, leads, assignments, orders, order_items, *_status_history,
-- notifications, analytics_events, platform_settings, feature_flags,
-- partners/partner_* (PII) beyond what is declared above.

-- Seed: ONLY structural/catalog data explicitly defined in the project
-- brief itself. Deliberately does NOT seed: pricing_rules (real prices),
-- partners, reviews, cases, articles, faqs, or LocalBusiness/contact data -
-- those require real business input and must be entered via /admin.

insert into public.services (slug, sort_order) values
  ('cisteni-sedacich-souprav', 1),
  ('cisteni-matraci', 2),
  ('cisteni-kobercu', 3),
  ('cisteni-zidli', 4);

insert into public.service_translations (service_id, locale, name)
select id, 'cs', case slug
  when 'cisteni-sedacich-souprav' then 'Čištění sedacích souprav'
  when 'cisteni-matraci' then 'Čištění matrací'
  when 'cisteni-kobercu' then 'Čištění koberců'
  when 'cisteni-zidli' then 'Čištění židlí'
end
from public.services;

insert into public.service_translations (service_id, locale, name)
select id, 'en', case slug
  when 'cisteni-sedacich-souprav' then 'Sofa cleaning'
  when 'cisteni-matraci' then 'Mattress cleaning'
  when 'cisteni-kobercu' then 'Carpet cleaning'
  when 'cisteni-zidli' then 'Chair cleaning'
end
from public.services;

insert into public.cities (slug, sort_order) values
  ('praha', 1), ('brno', 2), ('plzen', 3);

insert into public.city_translations (city_id, locale, name)
select id, 'cs', case slug when 'praha' then 'Praha' when 'brno' then 'Brno' when 'plzen' then 'Plzeň' end
from public.cities;
insert into public.city_translations (city_id, locale, name)
select id, 'en', case slug when 'praha' then 'Prague' when 'brno' then 'Brno' when 'plzen' then 'Pilsen' end
from public.cities;

insert into public.districts (city_id, slug, sort_order)
select c.id, 'praha-' || n, n
from public.cities c, generate_series(1, 22) n
where c.slug = 'praha';

insert into public.district_translations (district_id, locale, name)
select d.id, 'cs', 'Praha ' || n
from public.districts d
join public.cities c on c.id = d.city_id and c.slug = 'praha'
cross join lateral (select (regexp_match(d.slug, '\d+'))[1]::int as n) x;
insert into public.service_options (service_id, key, type, required, sort_order, step, config)
select id, v.key, v.type::service_option_type, v.required, v.sort_order, v.step, v.config::jsonb
from public.services, (values
    ('sofa_type', 'select', true, 1, 2, '{"options":[{"value":"corner","label":{"cs":"Rohová","en":"Corner"}},{"value":"straight","label":{"cs":"Přímá","en":"Straight"}},{"value":"armchair","label":{"cs":"Křeslo","en":"Armchair"}}]}'),
    ('seats_count', 'number', true, 2, 2, '{"min":1,"max":10}'),
    ('material', 'select', true, 3, 2, '{"options":[{"value":"fabric","label":{"cs":"Látka","en":"Fabric"}},{"value":"leather","label":{"cs":"Kůže","en":"Leather"}},{"value":"suede","label":{"cs":"Semiš","en":"Suede"}}]}'),
    ('soiling_level', 'select', true, 4, 3, '{"options":[{"value":"light","label":{"cs":"Lehké","en":"Light"}},{"value":"medium","label":{"cs":"Střední","en":"Medium"}},{"value":"heavy","label":{"cs":"Silné","en":"Heavy"}}]}'),
    ('has_stains', 'boolean', false, 5, 3, '{}'),
    ('has_odor', 'boolean', false, 6, 3, '{}'),
    ('extra_items', 'multiselect', false, 7, 5, '{"options":[{"value":"cushions","label":{"cs":"Polštáře","en":"Cushions"}},{"value":"covers","label":{"cs":"Potahy","en":"Covers"}}]}')
  ) as v(key, type, required, sort_order, step, config)
where slug = 'cisteni-sedacich-souprav';

insert into public.service_options (service_id, key, type, required, sort_order, step, config)
select id, v.key, v.type::service_option_type, v.required, v.sort_order, v.step, v.config::jsonb
from public.services, (values
    ('size', 'select', true, 1, 2, '{"options":[{"value":"single","label":{"cs":"Jednolůžko","en":"Single"}},{"value":"one_half","label":{"cs":"Jeden a půl lůžko","en":"One and a half"}},{"value":"double","label":{"cs":"Dvojlůžko","en":"Double"}},{"value":"king","label":{"cs":"King-size","en":"King-size"}}]}'),
    ('quantity', 'number', true, 2, 2, '{"min":1,"max":10}'),
    ('soiling_level', 'select', true, 3, 3, '{"options":[{"value":"light","label":{"cs":"Lehké","en":"Light"}},{"value":"medium","label":{"cs":"Střední","en":"Medium"}},{"value":"heavy","label":{"cs":"Silné","en":"Heavy"}}]}'),
    ('has_stains', 'boolean', false, 4, 3, '{}'),
    ('has_odor', 'boolean', false, 5, 3, '{}'),
    ('anti_allergen_treatment', 'boolean', false, 6, 5, '{}')
  ) as v(key, type, required, sort_order, step, config)
where slug = 'cisteni-matraci';

insert into public.service_options (service_id, key, type, required, sort_order, step, config)
select id, v.key, v.type::service_option_type, v.required, v.sort_order, v.step, v.config::jsonb
from public.services, (values
    ('size_preset', 'select', true, 1, 2, '{"options":[{"value":"small","label":{"cs":"Malý","en":"Small"}},{"value":"medium","label":{"cs":"Střední","en":"Medium"}},{"value":"large","label":{"cs":"Velký","en":"Large"}},{"value":"custom_m2","label":{"cs":"Zadat m²","en":"Enter m²"}}]}'),
    ('area_m2', 'number', false, 2, 2, '{"min":1,"max":200}'),
    ('material', 'select', true, 3, 2, '{"options":[{"value":"natural","label":{"cs":"Přírodní","en":"Natural"}},{"value":"synthetic","label":{"cs":"Syntetický","en":"Synthetic"}},{"value":"wool","label":{"cs":"Vlna","en":"Wool"}}]}'),
    ('soiling_level', 'select', true, 4, 3, '{"options":[{"value":"light","label":{"cs":"Lehké","en":"Light"}},{"value":"medium","label":{"cs":"Střední","en":"Medium"}},{"value":"heavy","label":{"cs":"Silné","en":"Heavy"}}]}'),
    ('has_stains', 'boolean', false, 5, 3, '{}'),
    ('pickup_required', 'boolean', false, 6, 5, '{}')
  ) as v(key, type, required, sort_order, step, config)
where slug = 'cisteni-kobercu';

insert into public.service_options (service_id, key, type, required, sort_order, step, config)
select id, v.key, v.type::service_option_type, v.required, v.sort_order, v.step, v.config::jsonb
from public.services, (values
    ('chair_type', 'select', true, 1, 2, '{"options":[{"value":"soft","label":{"cs":"Měkká","en":"Soft"}},{"value":"semi_soft","label":{"cs":"Polo-měkká","en":"Semi-soft"}}]}'),
    ('quantity', 'number', true, 2, 2, '{"min":1,"max":50}'),
    ('material', 'select', true, 3, 2, '{"options":[{"value":"fabric","label":{"cs":"Látka","en":"Fabric"}},{"value":"leather","label":{"cs":"Kůže","en":"Leather"}}]}'),
    ('soiling_level', 'select', true, 4, 3, '{"options":[{"value":"light","label":{"cs":"Lehké","en":"Light"}},{"value":"medium","label":{"cs":"Střední","en":"Medium"}},{"value":"heavy","label":{"cs":"Silné","en":"Heavy"}}]}'),
    ('has_stains', 'boolean', false, 5, 3, '{}')
  ) as v(key, type, required, sort_order, step, config)
where slug = 'cisteni-zidli';

insert into public.service_options (service_id, key, type, required, sort_order, step, config)
select id, 'express_drying', 'boolean', false, 90, 5, '{}'::jsonb from public.services
union all
select id, 'anti_allergen_addon', 'boolean', false, 91, 5, '{}'::jsonb from public.services
where slug <> 'cisteni-matraci';

insert into public.platform_settings (scope, platform_mode) values ('global', 'bootstrap');
