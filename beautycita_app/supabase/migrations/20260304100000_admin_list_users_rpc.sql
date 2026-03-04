-- RPC function for the admin users page.
-- Joins profiles with auth.users to expose email, auth providers, and password status.
-- SECURITY DEFINER so it can read auth.users (not accessible via anon key).

CREATE OR REPLACE FUNCTION admin_list_users(
  p_role text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_search text DEFAULT '',
  p_sort text DEFAULT 'created_at',
  p_asc boolean DEFAULT false,
  p_offset int DEFAULT 0,
  p_limit int DEFAULT 20
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
  v_total bigint;
  v_rows json;
  v_sort_expr text;
  v_dir text;
BEGIN
  -- Only admins may call this
  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'superadmin') THEN
    RAISE EXCEPTION 'Unauthorized: admin access required';
  END IF;

  -- Sanitise sort column to prevent injection
  v_sort_expr := CASE p_sort
    WHEN 'username'   THEN 'p.username'
    WHEN 'role'       THEN 'p.role'
    WHEN 'status'     THEN 'p.status'
    WHEN 'last_seen'  THEN 'p.last_seen'
    WHEN 'email'      THEN 'u.email'
    ELSE 'p.created_at'
  END;
  v_dir := CASE WHEN p_asc THEN 'ASC' ELSE 'DESC' END;

  -- Count
  SELECT COUNT(*)
  INTO v_total
  FROM profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE (p_role IS NULL OR p.role = p_role)
    AND (p_status IS NULL OR p.status = p_status)
    AND (p_search = '' OR
         p.username  ILIKE '%' || p_search || '%' OR
         p.full_name ILIKE '%' || p_search || '%' OR
         p.phone     ILIKE '%' || p_search || '%' OR
         u.email     ILIKE '%' || p_search || '%');

  -- Data (dynamic ORDER BY)
  EXECUTE format(
    $q$
    SELECT COALESCE(json_agg(t ORDER BY t.row_num), '[]'::json)
    FROM (
      SELECT
        p.id,
        p.username,
        p.full_name,
        p.role,
        p.phone,
        p.phone_verified_at,
        p.birthday,
        p.gender,
        p.home_address,
        p.avatar_url,
        p.created_at,
        p.updated_at,
        p.last_seen,
        p.status,
        u.email,
        u.email_confirmed_at,
        u.raw_app_meta_data->'providers' AS auth_providers,
        (u.encrypted_password IS NOT NULL
         AND u.encrypted_password <> '') AS has_password,
        u.last_sign_in_at,
        ROW_NUMBER() OVER() AS row_num
      FROM profiles p
      LEFT JOIN auth.users u ON u.id = p.id
      WHERE ($1 IS NULL OR p.role = $1)
        AND ($2 IS NULL OR p.status = $2)
        AND ($3 = '' OR
             p.username  ILIKE '%%' || $3 || '%%' OR
             p.full_name ILIKE '%%' || $3 || '%%' OR
             p.phone     ILIKE '%%' || $3 || '%%' OR
             u.email     ILIKE '%%' || $3 || '%%')
      ORDER BY %s %s NULLS LAST
      LIMIT $4 OFFSET $5
    ) t
    $q$,
    v_sort_expr, v_dir
  )
  INTO v_rows
  USING p_role, p_status, p_search, p_limit, p_offset;

  RETURN json_build_object('users', v_rows, 'total', v_total);
END;
$$;

-- Grant execute to authenticated users (RPC checks admin role internally)
GRANT EXECUTE ON FUNCTION admin_list_users TO authenticated;
