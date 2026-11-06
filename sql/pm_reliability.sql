-- 설비정기점검(PM_checksheet.html) 「MTBF·MTTR」 메뉴용 집계 함수 (Supabase omngtyewdaqpphnzeate, 2026-11 적용)
-- 생산일보 앱(Daily-Production-Report) kv_store 'tj_prod_daily_v1' 의 recs 를 월·설비별로 실시간 집계 (읽기 전용)
-- 가동(분) = 근무 - 휴식 - 정지 (생산일보 calc()와 동일), 고장건수 = fcnt, 고장정지(분) = fmin
-- 호출: POST /rest/v1/rpc/pm_reliability  {"p_year":2026}
create or replace function public.pm_reliability(p_year int)
returns table(month int, mc_no int, mc text, recs int, run_min numeric, fails int, fail_min numeric)
language sql stable security invoker set search_path = public
as $$
  with r as (
    select x from kv_store, jsonb_array_elements(coalesce(value->'recs','[]'::jsonb)) x
    where key = 'tj_prod_daily_v1' and left(x->>'date',4) = p_year::text
  ), c as (
    select extract(month from (x->>'date')::date)::int m,
      nullif(substring(x->>'mc' from '^\s*(\d+)'),'')::int no,
      x->>'mc' mc,
      greatest(0, greatest(0, coalesce(nullif(x->>'work','')::numeric,0) - coalesce(nullif(x->>'brk','')::numeric,0))
                 - coalesce(nullif(x->>'stop','')::numeric,0)) run,
      coalesce(nullif(x->>'fcnt','')::numeric,0) f,
      coalesce(nullif(x->>'fmin','')::numeric,0) fm
    from r
  )
  select m, no, min(mc), count(*)::int, sum(run), sum(f)::int, sum(fm)
  from c where no is not null group by m, no order by m, no;
$$;
grant execute on function public.pm_reliability(int) to anon, authenticated;
