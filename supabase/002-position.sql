-- ============================================================================
--  Миграция 002: поле position для ручной сортировки (этап 02)
--  Выполнить в SQL Editor после schema.sql. Скрипт идемпотентный.
-- ============================================================================

alter table public.projects add column if not exists position double precision not null default 1000;
alter table public.cards    add column if not exists position double precision not null default 1000;
alter table public.tasks    add column if not exists position double precision not null default 1000;

-- Задачи: сохраняем текущий порядок по времени создания (по 1000 на шаг).
with ranked as (
  select id, 1000.0 * row_number() over (partition by card_id order by created_at, id) as pos
  from public.tasks
)
update public.tasks t
   set position = r.pos
  from ranked r
 where t.id = r.id
   and t.position = 1000;   -- трогаем только ещё не тронутые записи

-- Карточки: порядок как в интерфейсе — новые сверху.
with ranked as (
  select id, 1000.0 * row_number() over (partition by project_id order by created_at desc, id) as pos
  from public.cards
)
update public.cards c
   set position = r.pos
  from ranked r
 where c.id = r.id
   and c.position = 1000;

-- Проекты: без изменений порядка, просто чтобы колонка была заполнена.
update public.projects set position = 1000 where position is null or position = 0;

-- Проверка
-- select id, title, position from public.tasks order by card_id, position limit 10;
