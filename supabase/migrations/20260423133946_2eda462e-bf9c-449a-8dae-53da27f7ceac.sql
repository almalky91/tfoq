DROP VIEW IF EXISTS public.leaderboard;

CREATE OR REPLACE FUNCTION public.get_leaderboard(_limit integer DEFAULT 10)
RETURNS TABLE (
  id uuid,
  full_name text,
  total_points integer,
  grade text,
  avatar_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.full_name, p.total_points, p.grade, p.avatar_url
  FROM public.profiles p
  WHERE public.has_role(p.id, 'student'::app_role)
    AND p.is_active = true
  ORDER BY p.total_points DESC
  LIMIT GREATEST(_limit, 1);
$$;

GRANT EXECUTE ON FUNCTION public.get_leaderboard(integer) TO anon, authenticated;