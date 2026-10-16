-- Phase 4: researchers export the weekly logs from the admin web.
-- Run after phase 3. Read-only; nothing is changed or deleted.
-- Same gate as moderation: allowlisted Google admin with MFA (AAL2).
-- Returns the latest row per (participant_code, week): codes and numbers only.
begin;

create or replace function public.youwell_research_export()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return coalesce((
    select jsonb_agg(to_jsonb(latest) order by latest.participant_code, latest.week)
    from (
      select distinct on (participant_code, week)
        participant_code, week, week_complete, opened_days, active_days, active,
        quests_done, ladder_gerak, ladder_istirahat, ladder_tidur, ladder_hidrasi,
        ladder_makan, ladder_jeda, delay_craving_count, delay_craving_completed,
        habit_swap_count, submitted_at
      from public.youwell_research_logs
      order by participant_code, week, submitted_at desc
    ) latest
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_research_export() from public, anon, authenticated;
grant execute on function public.youwell_research_export() to authenticated;

commit;
