-- Teacher subject assignments (delegation)
CREATE TABLE public.teacher_subjects (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  teacher_id UUID NOT NULL,
  subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  assigned_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (teacher_id, subject_id)
);

CREATE INDEX idx_teacher_subjects_teacher ON public.teacher_subjects(teacher_id);
CREATE INDEX idx_teacher_subjects_subject ON public.teacher_subjects(subject_id);

ALTER TABLE public.teacher_subjects ENABLE ROW LEVEL SECURITY;

-- Admins manage all assignments
CREATE POLICY "Admins manage teacher subjects"
  ON public.teacher_subjects
  FOR ALL
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Teachers view their own assignments
CREATE POLICY "Teachers view own assignments"
  ON public.teacher_subjects
  FOR SELECT
  TO authenticated
  USING (teacher_id = auth.uid());

-- Helper: check whether a teacher is assigned a subject
CREATE OR REPLACE FUNCTION public.teacher_has_subject(_teacher_id UUID, _subject_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.teacher_subjects
    WHERE teacher_id = _teacher_id AND subject_id = _subject_id
  )
$$;

-- Tighten questions policies: teachers can only insert/update/delete questions for their assigned subjects
DROP POLICY IF EXISTS "Teachers insert questions" ON public.questions;
CREATE POLICY "Teachers insert questions"
  ON public.questions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.has_role(auth.uid(), 'admin')
    OR (
      public.has_role(auth.uid(), 'teacher')
      AND public.teacher_has_subject(auth.uid(), subject_id)
    )
  );

DROP POLICY IF EXISTS "Teachers update own questions" ON public.questions;
CREATE POLICY "Teachers update own questions"
  ON public.questions
  FOR UPDATE
  TO authenticated
  USING (
    public.has_role(auth.uid(), 'admin')
    OR (created_by = auth.uid() AND public.teacher_has_subject(auth.uid(), subject_id))
  );

DROP POLICY IF EXISTS "Teachers delete own questions" ON public.questions;
CREATE POLICY "Teachers delete own questions"
  ON public.questions
  FOR DELETE
  TO authenticated
  USING (
    public.has_role(auth.uid(), 'admin')
    OR (created_by = auth.uid() AND public.teacher_has_subject(auth.uid(), subject_id))
  );