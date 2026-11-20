# Переход на GitHub Pages + Supabase

План к [index.html](../index.html): как выложить на телефон и как добавить облако, ничего не сломав.

## 0. Главное: два независимых шага

| Шаг | Что даёт | Нужен ли Supabase |
|---|---|---|
| **1. GitHub Pages + PWA** | приложение открывается по ссылке, ставится на домашний экран телефона, работает офлайн | **Нет** |
| **2. Supabase** | одни и те же данные на телефоне и компьютере, резервная копия в облаке | Да |

Поэтому предлагаю не ждать Supabase: сначала выкладываем — и ты уже сегодня пользуешься с телефона. Supabase подключаем вторым этапом.

## 1. Что мне нужно от тебя (чек-лист)

**Этап 1 — Pages (5 минут):**

1. Создать на GitHub пустой репозиторий, например `to-diary` (public — для бесплатного Pages это обязательно).
2. Прислать ссылку на него (`https://github.com/<логин>/to-diary`).

**Этап 2 — Supabase (10 минут):**

3. В проекте Supabase: **Project Settings → API** — прислать **Project URL** и **anon public key** (`anon` — публичный ключ, его не страшно встраивать в клиент; `service_role` никогда не присылай).
4. **Authentication → Providers → Email**: выключить «Confirm email» (иначе после регистрации письмо не придёт без своего SMTP).
5. Выполнить мой SQL-скрипт в **SQL Editor** (ниже) — или дать мне 2 минуты после того, как пришлёшь URL/ключ, я сгенерирую файл миграции и ты вставишь его целиком.

Чтобы я мог проверить подключение сам, понадобился бы доступ к `*.supabase.co` из моей песочницы — сейчас он закрыт. Поэтому схема проверки такая: я пишу код, ты открываешь страницу, при ошибке присылаешь текст из консоли (F12 → Console), я правлю.

## 2. Почему не «просто загрузить файл на FTP»

GitHub Pages даёт HTTPS (нужен для буфера обмена, установки PWA и запросов к Supabase), стабильный URL и версионирование. Это бесплатно и без сервера.

## 3. Структура репозитория

```
/
  index.html            ← само приложение (открывается двойным щелчком)
  manifest.webmanifest  ← имя, иконки, standalone
  sw.js                 ← service worker: кэш оболочки, работа офлайн
  icons/icon-192.png
  icons/icon-512.png
  README.md
```

`index.html` — тот же один файл, но с подключением SDK Supabase (через `esm.sh`/`jsdelivr` CDN или bundle; решим при подключении).

## 4. Схема БД в Supabase

Клиентские id остаются UUID, значит задачи можно создавать офлайн и потом синхронизировать.

```sql
-- ===== таблицы =====
create table if not exists public.projects (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name       text not null,
  note       text not null default '',
  position   double precision not null default 1000,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.cards (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  name       text not null,
  date_label text not null default '',
  position   double precision not null default 1000,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.tasks (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  card_id    uuid not null references public.cards(id) on delete cascade,
  title      text not null,
  note       text not null default '',
  priority   text not null default 'normal' check (priority in ('high','normal','low')),
  due        date,
  done       boolean not null default false,
  done_at    timestamptz,
  position   double precision not null default 1000,
  subs       jsonb not null default '[]'::jsonb,
  tags       text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ===== индексы =====
create index if not exists projects_owner_idx on public.projects(owner_id, updated_at desc);
create index if not exists cards_project_idx  on public.cards(project_id, position);
create index if not exists cards_owner_idx    on public.cards(owner_id, updated_at desc);
create index if not exists tasks_card_idx     on public.tasks(card_id, position);
create index if not exists tasks_owner_idx    on public.tasks(owner_id, updated_at desc);

-- ===== updated_at всегда ставит сервер =====
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists trg_projects_touch on public.projects;
create trigger trg_projects_touch before update on public.projects
for each row execute function public.touch_updated_at();

drop trigger if exists trg_cards_touch on public.cards;
create trigger trg_cards_touch before update on public.cards
for each row execute function public.touch_updated_at();

drop trigger if exists trg_tasks_touch on public.tasks;
create trigger trg_tasks_touch before update on public.tasks
for each row execute function public.touch_updated_at();

-- ===== RLS: каждый видит только своё =====
alter table public.projects enable row level security;
alter table public.cards    enable row level security;
alter table public.tasks    enable row level security;

drop policy if exists projects_own on public.projects;
create policy projects_own on public.projects
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists cards_own on public.cards;
create policy cards_own on public.cards
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists tasks_own on public.tasks;
create policy tasks_own on public.tasks
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- ===== (опционально) realtime для второго устройства =====
-- alter publication supabase_realtime add table public.tasks;
```

Почему так:

* `subs` — **jsonb внутри задачи**: подпункты всегда грузятся вместе с задачей, отдельная таблица дала бы лишние запросы и сложную синхронизацию. Для 10–50 подпунктов на задачу это нормально.
* **soft delete** (`deleted_at`) вместо физического: удаление должно доехать до второго устройства, иначе запись «воскреснет» при следующей синхронизации.
* `position double precision` — для drag&drop: вставляем между соседями как `(prev + next) / 2`.

## 5. Авторизация

| Вариант | Плюсы | Минусы |
|---|---|---|
| **Email + пароль** (рекомендую) | работает без SMTP, вход один раз, сессия живёт в браузере | надо помнить пароль |
| Magic link (письмо со ссылкой) | ничего не помнишь | нужен SMTP; дефолтный лимит — несколько писем в час |
| Анонимный вход + секретная ссылка | быстрее всего | не переносится на второе устройство |

Для «я и семья»: сначала email+пароль и RLS по `owner_id`. Общий доступ (несколько людей к одному проекту) — отдельный этап: таблица `members(project_id, user_id, role)` и политика «владелец ИЛИ участник».

## 6. Синхронизация: как не потерять данные

Локальное хранилище остаётся **источником правды**, облако — реплика.

1. **Старт**: если есть сессия — `select … where updated_at > last_pull` (или всё, если данных мало), мержим по `id`, конфликт решаем по `updated_at`.
2. **Изменение**: сразу обновляем состояние и UI (оптимистично), запись кладём в очередь `pending[]` в localStorage.
3. **Отправка**: `upsert` пачками; при сетевой ошибке — ретрай с backoff; при закрытии вкладки очередь сохраняется.
4. **Удаление**: `update … set deleted_at = now()`, локально тоже помечаем; на других устройствах такие записи скрываются.
5. **Конфликты**: last-write-wins по серверному `updated_at`. Для личного дневника этого достаточно; если понадобится — перейдём на CRDT/`updated_at` по полям.
6. **Индикатор**: в шапке «облако: синхронизировано / есть несохранённое / офлайн».

## 7. GitHub Pages: шаги

1. Репозиторий public, ветка `main`.
2. Settings → Pages → Source: **Deploy from a branch**, ветка `main`, папка `/ (root)`.
3. Через минуту страница: `https://<логин>.github.io/to-diary/`.
4. Обновление: `git push` — Pages пересобирает сам.

Команды для тебя (после того как пришлёшь ссылку на репозиторий, я подготовлю файлы):

```bash
git init
git add .
git commit -m "To Do: проекты, карточки, задачи"
git branch -M main
git remote add origin https://github.com/<логин>/to-diary.git
git push -u origin main
```

## 8. PWA: чтобы «как приложение» на телефоне

* `manifest.webmanifest`: `name`, `short_name`, `start_url: "./"`, `display: "standalone"`, `theme_color`, иконки 192/512.
* `sw.js`: кэширует `index.html`, манифест и иконки; стратегия «сначала кэш, потом сеть» для оболочки; версия кэша бампается при релизе.
* iOS: добавить `apple-touch-icon` — установка через «Поделиться → На экран Домой».
* Android Chrome: «Установить приложение» / «Добавить на главный экран».

## 9. Безопасность

* `anon` key публичен — это нормально, защита в RLS.
* `service_role` key **никогда** не попадает в браузер.
* RLS включён на всех таблицах, политика `owner_id = auth.uid()`.
* Supabase Auth: включить лимиты и «Confirm email» по вкусу; хранить пароль в менеджере паролей.

## 10. Порядок работ

| Этап | Что делаю я | Что делаешь ты | Время |
|---|---|---|---|
| 1 | готовлю `index.html` + `manifest` + `sw.js` + иконки, инструкцию по push | создаёшь репозиторий, пушишь, включаешь Pages | ~15 мин |
| 2 | подключаю Supabase SDK, экран входа, синхронизацию, индикатор | присылаешь URL+anon, выключаешь Confirm email, выполняешь SQL | ~30 мин |
| 3 | проверяем вход на телефоне и компьютере, правим ошибки из консоли | тестируешь | по факту |
| 4 | (опционально) realtime и общий доступ для семьи | решаем, нужно ли | потом |

## 11. Риски

* **Кэш браузера**: после обновления `index.html` телефон может показывать старую версию — лечится версией в `sw.js` и `Ctrl+F5`/переустановкой PWA.
* **Потеря данных при чистке браузера** — до подключения Supabase экспорт JSON обязателен (кнопка в сайдбаре).
* **Смешение локальных и облачных данных**: первый вход должен аккуратно слить локальные записи с облачными, а не затереть их. Это отдельный шаг с подтверждением пользователю.
* **Realtime не бесплатен по трафику**, но для личного использования — с запасом.

## 12. Следующий шаг после этого документа

1. Ты создаёшь репозиторий и присылаешь ссылку → я готовлю файлы для Pages и PWA.
2. Ты присылаешь Supabase URL + anon key → я подключаю вход и синхронизацию.
3. Дальше — по консоли браузера, если что-то пойдёт не так.
