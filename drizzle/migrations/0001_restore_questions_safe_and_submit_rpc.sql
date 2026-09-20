-- questions_safe: student-facing question list without the answer key
DROP VIEW IF EXISTS public.questions_safe;
CREATE VIEW public.questions_safe AS
SELECT
  id, subject_id, question_text,
  option_a, option_b, option_c, option_d,
  explanation, difficulty, points,
  created_by, created_at, updated_at
FROM public.questions;

GRANT SELECT ON public.questions_safe TO anon, authenticated;

-- idempotency key for attempts
ALTER TABLE public.quiz_attempts ADD COLUMN IF NOT EXISTS client_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS quiz_attempts_client_id_key
  ON public.quiz_attempts (client_id) WHERE client_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.submit_quiz_attempt(
  p_question_id  UUID,
  p_selected     CHAR(1),
  p_client_id    TEXT
)
RETURNS TABLE (
  attempt_id     UUID,
  is_correct     BOOLEAN,
  points_earned  INTEGER,
  correct_option CHAR(1)
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id  UUID := auth.uid();
  v_correct     CHAR(1);
  v_points      INTEGER;
  v_is_correct  BOOLEAN;
  v_earned      INTEGER;
  v_attempt_id  UUID;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_client_id IS NULL OR length(p_client_id) < 8 OR length(p_client_id) > 128 THEN
    RAISE EXCEPTION 'invalid client_id' USING ERRCODE = '22023';
  END IF;

  SELECT a.id, a.is_correct, a.points_earned, q.correct_option
    INTO v_attempt_id, v_is_correct, v_earned, v_correct
    FROM public.quiz_attempts a
    JOIN public.questions q ON q.id = a.question_id
   WHERE a.client_id = p_client_id;

  IF v_attempt_id IS NOT NULL THEN
    RETURN QUERY SELECT v_attempt_id, v_is_correct, v_earned, upper(v_correct)::char(1);
    RETURN;
  END IF;

  SELECT q.correct_option, q.points
    INTO v_correct, v_points
    FROM public.questions q
   WHERE q.id = p_question_id;

  IF v_correct IS NULL THEN
    RAISE EXCEPTION 'question not found' USING ERRCODE = 'P0002';
  END IF;

  v_is_correct := (upper(p_selected) = upper(v_correct));
  v_earned     := CASE WHEN v_is_correct THEN v_points ELSE 0 END;

  BEGIN
    INSERT INTO public.quiz_attempts (
      student_id, question_id, selected_option,
      is_correct, points_earned, client_id
    ) VALUES (
      v_student_id, p_question_id, upper(p_selected),
      v_is_correct, v_earned, p_client_id
    )
    RETURNING id INTO v_attempt_id;
  EXCEPTION WHEN unique_violation THEN
    SELECT a.id, a.is_correct, a.points_earned, q.correct_option
      INTO v_attempt_id, v_is_correct, v_earned, v_correct
      FROM public.quiz_attempts a
      JOIN public.questions q ON q.id = a.question_id
     WHERE a.client_id = p_client_id;
  END;

  RETURN QUERY SELECT v_attempt_id, v_is_correct, v_earned, upper(v_correct)::char(1);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_quiz_attempt(UUID, CHAR, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_quiz_attempt(UUID, CHAR, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_quiz_attempt(UUID, CHAR, TEXT) TO service_role;
GRANT SELECT ON public.quiz_attempts TO authenticated;