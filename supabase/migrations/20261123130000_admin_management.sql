insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('event-posters', 'event-posters', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "Admins can upload event posters"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'event-posters' and (select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create policy "Admins can delete event posters"
  on storage.objects for delete to authenticated
  using (bucket_id = 'event-posters' and (select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create policy "Anyone can view event posters"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'event-posters');

revoke delete on public.events from authenticated;
grant update (guest_name, ticket_type), delete on public.guest_list_entries to authenticated;

create policy "Admins can update guest list entries"
  on public.guest_list_entries for update to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create policy "Admins can delete guest list entries"
  on public.guest_list_entries for delete to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
