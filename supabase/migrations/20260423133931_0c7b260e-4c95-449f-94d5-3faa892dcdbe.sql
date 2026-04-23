-- Public leaderboard view that exposes only non-sensitive student ranking data
CREATE OR REPLACE VIEW public.leaderboard
WITH (security_invoker = off) AS
SELECT
  p.id,
  p.full_name,
  p.total_points,
  p.grade,
  p.avatar_url
FROM public.profiles p
WHERE public.has_role(p.id, 'student'::app_role)
  AND p.is_active = true
ORDER BY p.total_points DESC;

GRANT SELECT ON public.leaderboard TO anon, authenticated;