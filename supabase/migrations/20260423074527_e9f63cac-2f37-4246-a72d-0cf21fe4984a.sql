-- Allow students to access public content and content shared at subject level
CREATE OR REPLACE FUNCTION public.can_access_content(_user_id uuid, _owner_id uuid, _subject_id uuid, _visibility content_visibility)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT
    public.has_role(_user_id, 'admin'::app_role)
    OR _owner_id = _user_id
    OR (_visibility = 'public')
    OR (_visibility = 'subject' AND public.has_role(_user_id, 'teacher'::app_role)
         AND public.teacher_has_subject(_user_id, _subject_id))
$function$;