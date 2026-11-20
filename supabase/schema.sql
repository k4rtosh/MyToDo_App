-- ============================================================================
--  To Do · схема для Supabase
--  Куда вставлять: Dashboard → SQL Editor → New query → вставить → Run
--
--  Особенность: приложение генерирует короткие текстовые id (pmvz0ggsa7yaj,
--  cmvz0ggsb779r, tmvz…), поэтому первичные ключи — text, а не uuid.
--  created_at приходит с клиента (в выгрузке это createdAt в мс) — так
--  сохраняется порядок карточек после синхронизации.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. ТАБЛИЦЫ
-- ---------------------------------------------------------------------------
create table if not exists public.projects (
  id         text primary key,
  owner_id   uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  name       text        not null default '',
  note       text        not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.cards (
  id         text primary key,
  owner_id   uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  project_id text        not null references public.projects(id) on delete cascade,
  name       text        not null default '',
  date_label text        not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.tasks (
  id         text primary key,
  owner_id   uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  card_id    text        not null references public.cards(id) on delete cascade,
  title      text        not null default '',
  note       text        not null default '',
  priority   text        not null default 'normal' check (priority in ('high', 'normal', 'low')),
  due        date,
  done       boolean     not null default false,
  done_at    timestamptz,
  subs       jsonb       not null default '[]'::jsonb,
  tags       text[]      not null default '{}',
  links      text[]      not null default '{}',
  paths      text[]      not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ---------------------------------------------------------------------------
-- 2. ИНДЕКСЫ (выборки по владельцу, карточке, проекту + синхронизация)
-- ---------------------------------------------------------------------------
create index if not exists projects_owner_idx on public.projects (owner_id, updated_at desc);
create index if not exists cards_project_idx  on public.cards   (project_id, created_at desc);
create index if not exists cards_owner_idx    on public.cards   (owner_id, updated_at desc);
create index if not exists tasks_card_idx     on public.tasks   (card_id, created_at);
create index if not exists tasks_owner_idx    on public.tasks   (owner_id, updated_at desc);

-- ---------------------------------------------------------------------------
-- 3. updated_at ВСЕГДА СТАВИТ СЕРВЕР (по нему разрешаются конфликты)
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_projects_touch on public.projects;
create trigger trg_projects_touch before update on public.projects
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_cards_touch on public.cards;
create trigger trg_cards_touch before update on public.cards
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_tasks_touch on public.tasks;
create trigger trg_tasks_touch before update on public.tasks
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 4. RLS: каждый видит и меняет только своё
-- ---------------------------------------------------------------------------
alter table public.projects enable row level security;
alter table public.cards    enable row level security;
alter table public.tasks    enable row level security;

drop policy if exists projects_own on public.projects;
create policy projects_own on public.projects
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists cards_own on public.cards;
create policy cards_own on public.cards
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists tasks_own on public.tasks;
create policy tasks_own on public.tasks
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 5. ПРАВА: анонимному доступу — ничего, вошедшему — чтение и запись
-- ---------------------------------------------------------------------------
revoke all on public.projects from anon;
revoke all on public.cards    from anon;
revoke all on public.tasks    from anon;

grant select, insert, update, delete on public.projects to authenticated;
grant select, insert, update, delete on public.cards    to authenticated;
grant select, insert, update, delete on public.tasks    to authenticated;

-- ---------------------------------------------------------------------------
-- 6. ПРОВЕРКА (должно вернуть 3 строки, rowsecurity = true)
-- ---------------------------------------------------------------------------
-- select tablename, rowsecurity from pg_tables where schemaname = 'public';
--
-- select count(*) as проектов from public.projects;   -- после первого входа
--
-- ОПЦИОНАЛЬНО: realtime для мгновенных обновлений на втором устройстве
-- alter publication supabase_realtime add table public.projects, public.cards, public.tasks;
