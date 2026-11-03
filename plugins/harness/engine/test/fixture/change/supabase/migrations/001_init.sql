create view public.v_orders as select * from orders;
create view public.v_safe with (security_invoker = true) as select * from orders;
create policy p on orders for insert with check (auth.uid() = user_id);
