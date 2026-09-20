-- 1) Safe view for student-facing template questions (no correct_option).
-- SECURITY DEFINER semantics (default) so students can read questions of
-- templates they are allowed to see, while the base table stays admin/teacher only.
DROP VIEW IF EXISTS public.quiz_template_questions_safe;

CREATE VIEW public.quiz_template_questions_safe AS
SELECT
  q.id, q.template_id, q.question_text,
  q.option_a, q.option_b, q.option_c, q.option_d,
  q.explanation, q.points, q.position, q.created_at
FROM public.quiz_template_questions q
JOIN public.quiz_templates t ON t.id = q.template_id
WHERE t.visibility = 'public'
   OR (auth.uid() IS NOT NULL AND public.can_access_content(auth.uid(), t.created_by, t.subject_id, t.visibility));

GRANT SELECT ON public.quiz_template_questions_safe TO anon, authenticated;

-- 2) Server-side answer key lookup, only usable after the student answered.
CREATE OR REPLACE FUNCTION public.check_template_answer(p_question_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT lower(q.correct_option::text)
  FROM public.quiz_template_questions q
  JOIN public.quiz_templates t ON t.id = q.template_id
  WHERE q.id = p_question_id
    AND (
      t.visibility = 'public'
      OR (auth.uid() IS NOT NULL AND public.can_access_content(auth.uid(), t.created_by, t.subject_id, t.visibility))
    );
$$;

REVOKE ALL ON FUNCTION public.check_template_answer(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_template_answer(UUID) TO anon, authenticated;

-- 3) Restore FAQ entries table used by the chatbot and admin FAQ manager.
CREATE TABLE IF NOT EXISTS public.faq_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  keywords TEXT[] NOT NULL DEFAULT '{}',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.faq_entries ADD COLUMN IF NOT EXISTS keywords TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_faq_active_sort ON public.faq_entries (is_active, sort_order);

GRANT SELECT ON public.faq_entries TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.faq_entries TO authenticated;
GRANT ALL ON public.faq_entries TO service_role;

ALTER TABLE public.faq_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read active FAQs" ON public.faq_entries;
CREATE POLICY "Anyone can read active FAQs"
  ON public.faq_entries FOR SELECT
  USING (is_active = true);

DROP POLICY IF EXISTS "Admins read all FAQs" ON public.faq_entries;
CREATE POLICY "Admins read all FAQs"
  ON public.faq_entries FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Admins manage FAQs" ON public.faq_entries;
CREATE POLICY "Admins manage FAQs"
  ON public.faq_entries FOR ALL
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

DO $do$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'faq_entries_touch_updated_at') THEN
    CREATE TRIGGER faq_entries_touch_updated_at
      BEFORE UPDATE ON public.faq_entries
      FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
  END IF;
END
$do$;

INSERT INTO public.faq_entries (question, answer, sort_order, is_active)
SELECT * FROM (VALUES
  ('ما هي منصة تفوّق؟', 'منصة تعليمية تفاعلية لطالبات الثانوية تساعد على التحضير لاختباري التحصيلي والقدرات عبر عجلة أسئلة، اختبارات محاكية، وألعاب تعليمية.', 1, true),
  ('كيف أبدأ في المنصة؟', 'أنشئي حساباً جديداً من صفحة تسجيل الدخول، ثم اختاري دورك (طالبة / معلمة / وليّة أمر)، وبعدها يمكنك بدء عجلة الاختبارات أو تصفح الاختبارات المحاكية.', 2, true),
  ('هل استخدام المنصة مجاني؟', 'نعم، المنصة مجانية لجميع طالبات الثانوية في حدود الاستخدام العادل.', 3, true)
) AS v(question, answer, sort_order, is_active)
WHERE NOT EXISTS (SELECT 1 FROM public.faq_entries);