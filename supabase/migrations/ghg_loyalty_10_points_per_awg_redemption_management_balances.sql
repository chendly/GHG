-- GHG loyalty launch: 1 point per AWG earned; 10 points for AWG 1 in rewards.
-- Management-only customer overview with earned, reserved/redeemed, and available points.
-- This change applies ONLY to the GHG tenant; online checkout remains unchanged.

UPDATE public.loyalty_program_settings s
SET points_per_awg = 1,
    points_per_reward = 10,
    reward_awg = 1.00,
    redemption_enabled = true,
    enabled = true,
    updated_at = now()
FROM public.tenants t
WHERE s.tenant_id = t.id
  AND t.slug = 'gordo-hospitality-group'
  AND t.active = true;

CREATE OR REPLACE FUNCTION public.get_customer_loyalty(
  p_tenant_slug text,
  p_search text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_tenant uuid;
  v_rate numeric;
  v_enabled boolean;
  v_redemption boolean;
  v_cost integer;
  v_reward numeric;
  v_customers jsonb;
BEGIN
  SELECT t.id, coalesce(ls.points_per_awg,0),
         coalesce(ls.enabled,false),
         coalesce(ls.redemption_enabled,false),
         coalesce(ls.points_per_reward,10),
         coalesce(ls.reward_awg,1)
  INTO v_tenant, v_rate, v_enabled, v_redemption, v_cost, v_reward
  FROM public.tenants t
  JOIN public.staff_memberships sm ON sm.tenant_id=t.id
    AND sm.user_id=auth.uid()
    AND sm.active=true
    AND sm.role::text IN ('owner','admin','manager')
  LEFT JOIN public.loyalty_program_settings ls ON ls.tenant_id=t.id
  WHERE t.slug=p_tenant_slug
    AND t.slug='gordo-hospitality-group'
    AND t.active=true
  LIMIT 1;

  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'Manager access required' USING ERRCODE='42501';
  END IF;
  IF NOT v_enabled THEN
    RETURN pg_catalog.jsonb_build_object('enabled',false,'customers','[]'::jsonb);
  END IF;
  IF p_search IS NOT NULL AND length(p_search)>100 THEN
    RAISE EXCEPTION 'Search is too long';
  END IF;

  WITH per_order AS (
    SELECT o.id,o.customer_phone_key,o.created_at,
           greatest(least(o.total,coalesce(sum(op.amount) FILTER(
                WHERE op.status='completed'),0)),0) AS eligible_paid_awg
    FROM public.orders o
    LEFT JOIN public.order_payments op
      ON op.order_id=o.id AND op.tenant_id=o.tenant_id
    WHERE o.tenant_id=v_tenant
      AND o.customer_phone_key IS NOT NULL
      AND length(o.customer_phone_key)>=7
      AND o.payment_status::text='paid'
      AND o.status::text<>'cancelled'
    GROUP BY o.id
  ),
  earnings AS (
    SELECT customer_phone_key,
       count(*) FILTER(WHERE eligible_paid_awg>0)::integer AS paid_orders,
       coalesce(sum(eligible_paid_awg),0)::numeric(12,2) AS paid_spend_awg,
       coalesce(sum(floor(eligible_paid_awg*v_rate)),0)::integer AS earned_points,
       max(created_at) FILTER(WHERE eligible_paid_awg>0) AS last_paid_order_at
    FROM per_order
    GROUP BY customer_phone_key
  ),
  deductions AS (
    SELECT phone_key,
       coalesce(sum(points_spent) FILTER(WHERE status='redeemed'),0)::integer AS redeemed_points,
       coalesce(sum(points_spent) FILTER(WHERE status='reserved'),0)::integer AS reserved_points
    FROM public.loyalty_redemptions
    WHERE tenant_id=v_tenant
    GROUP BY phone_key
  ),
  profiles AS (
    SELECT cp.id,cp.customer_name,cp.display_phone,
      coalesce(e.paid_orders,0) AS paid_orders,
      coalesce(e.paid_spend_awg,0) AS paid_spend_awg,
      coalesce(e.earned_points,0) AS earned_points,
      coalesce(d.redeemed_points,0) AS redeemed_points,
      coalesce(d.reserved_points,0) AS reserved_points,
      greatest(coalesce(e.earned_points,0)
        -coalesce(d.redeemed_points,0)
        -coalesce(d.reserved_points,0),0) AS available_points,
      e.last_paid_order_at,
      cp.last_seen_at,
      EXISTS(SELECT 1 FROM public.loyalty_customer_enrollments le
             WHERE le.tenant_id=cp.tenant_id
               AND le.phone_key=cp.phone_key) AS enrolled
    FROM public.customer_profiles cp
    LEFT JOIN earnings e ON e.customer_phone_key=cp.phone_key
    LEFT JOIN deductions d ON d.phone_key=cp.phone_key
    WHERE cp.tenant_id=v_tenant
      AND cp.phone_key IS NOT NULL
      AND length(cp.phone_key)>=7
      AND (nullif(trim(coalesce(p_search,'')),'') IS NULL
           OR coalesce(cp.customer_name,'') ILIKE '%'||trim(p_search)||'%'
           OR coalesce(cp.display_phone,'') ILIKE '%'||trim(p_search)||'%')
  )
  SELECT coalesce(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'customer_id',p.id,
      'name',p.customer_name,
      'phone',p.display_phone,
      'paid_orders',p.paid_orders,
      'paid_spend_awg',p.paid_spend_awg,
      'earned_points',p.earned_points,
      'redeemed_points',p.redeemed_points,
      'reserved_points',p.reserved_points,
      'available_points',p.available_points,
      'redeemable_awg',floor(p.available_points::numeric/v_cost)*v_reward,
      'last_order_at',p.last_paid_order_at,
      'enrolled',p.enrolled
    )
    ORDER BY p.available_points DESC,p.last_seen_at DESC
  ),'[]'::jsonb)
  INTO v_customers
  FROM profiles p;

  RETURN pg_catalog.jsonb_build_object(
    'enabled',true,
    'points_per_awg',v_rate,
    'redemption_enabled',v_redemption,
    'points_per_reward',v_cost,
    'reward_awg',v_reward,
    'customers',v_customers,
    'points_note','Points earned from eligible completed paid orders only; redemption reserves points until payment, and cancellation or void releases them.'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_customer_loyalty(text,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_customer_loyalty(text,text)
  TO authenticated,service_role;
