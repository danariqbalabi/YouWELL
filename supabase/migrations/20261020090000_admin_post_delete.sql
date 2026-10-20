-- Phase 7: admins (allowlisted, with MFA) can delete any Community post,
-- including ones already published. Run after phases 1-6.

-- The queue also lists the latest published posts, so a post that nobody
-- reported can still be removed. Older app builds ignore the extra key.
create or replace function public.youwell_moderation_queue()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return jsonb_build_object(
    'pending', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'alias', p.alias, 'body', p.body,
        'image_path', p.image_path, 'created_at', p.created_at
      ) order by p.created_at)
      from public.youwell_posts p where p.status = 'pending'
    ), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'post_id', r.post_id, 'reason', r.reason,
        'created_at', r.created_at, 'alias', p.alias, 'body', p.body,
        'image_path', p.image_path, 'status', p.status
      ) order by r.created_at)
      from public.youwell_reports r join public.youwell_posts p on p.id = r.post_id
      where r.resolved_at is null
    ), '[]'::jsonb),
    'published', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'alias', p.alias, 'body', p.body,
        'image_path', p.image_path, 'created_at', p.created_at,
        'status', p.status
      ) order by p.created_at desc)
      from (
        select * from public.youwell_posts
        where status = 'approved'
        order by created_at desc
        limit 100
      ) p
    ), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.youwell_moderation_queue() from public, anon, authenticated;
grant execute on function public.youwell_moderation_queue() to authenticated;

-- Deletes any post; reactions and reports go with it (cascade). Returns the
-- photo path so the admin app can delete the file (storage policy
-- "Community photo delete own or admin" already allows it).
create or replace function public.admin_delete_youwell_post(p_post uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare photo text;
begin
  perform private.youwell_require_admin();
  delete from public.youwell_posts where id = p_post returning image_path into photo;
  if not found then raise exception 'Post not found' using errcode = 'P0002'; end if;
  return photo;
end;
$$;
revoke all on function public.admin_delete_youwell_post(uuid) from public, anon, authenticated;
grant execute on function public.admin_delete_youwell_post(uuid) to authenticated;
