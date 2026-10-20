-- Phase 8: admins (allowlisted, with MFA) can reach every published post,
-- not only the latest 100: search by alias or text, newest first, and load
-- older pages with a cursor. Run after phase 7.

create or replace function public.youwell_admin_published_posts(
  p_query text default null,
  p_before timestamptz default null,
  p_limit int default 30
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  q text := nullif(btrim(coalesce(p_query, '')), '');
  size int := least(greatest(coalesce(p_limit, 30), 1), 100);
begin
  perform private.youwell_require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'alias', p.alias, 'body', p.body,
      'image_path', p.image_path, 'created_at', p.created_at,
      'status', p.status
    ) order by p.created_at desc, p.id desc)
    from (
      select * from public.youwell_posts
      where status = 'approved'
        and (p_before is null or created_at < p_before)
        and (q is null
             or alias ilike '%' || q || '%'
             or body ilike '%' || q || '%')
      order by created_at desc, id desc
      limit size
    ) p
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_admin_published_posts(text, timestamptz, int) from public, anon, authenticated;
grant execute on function public.youwell_admin_published_posts(text, timestamptz, int) to authenticated;
