-- Auto-confirm password-based signups while the product runs without email confirmation.
-- The app uses email + password auth and immediately signs users in after account creation.

create or replace function private.auto_confirm_auth_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is not null and new.email_confirmed_at is null then
    new.email_confirmed_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists auto_confirm_auth_email_on_signup on auth.users;

create trigger auto_confirm_auth_email_on_signup
before insert on auth.users
for each row
execute function private.auto_confirm_auth_email();

update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now())
where email is not null
  and email_confirmed_at is null;
