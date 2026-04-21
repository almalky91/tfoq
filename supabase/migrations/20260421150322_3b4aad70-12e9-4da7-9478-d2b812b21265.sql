
-- Site content table for editable landing page content
CREATE TABLE IF NOT EXISTS public.site_content (
  id TEXT PRIMARY KEY,
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID
);

ALTER TABLE public.site_content ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view site content"
ON public.site_content FOR SELECT
USING (true);

CREATE POLICY "Admins manage site content"
ON public.site_content FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TRIGGER site_content_updated_at
BEFORE UPDATE ON public.site_content
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Seed default landing content
INSERT INTO public.site_content (id, content) VALUES
('hero', '{
  "badge": "منصة تعليمية معتمدة لطالبات الثانوية",
  "title_line1": "تفوّقي في",
  "title_line2": "التحصيلي والقدرات",
  "description": "منصة تفاعلية متكاملة تساعدك على إتقان مهارات اختبارَي التحصيلي والقدرات عبر عجلة أسئلة ذكية، نظام نقاط، ولوحة ترتيب محفّزة.",
  "cta_primary": "ابدئي رحلتك الآن",
  "cta_secondary": "استكشفي المميزات",
  "stats": [
    {"v": "1,200+", "l": "طالبة مسجلة"},
    {"v": "5,000+", "l": "سؤال تفاعلي"},
    {"v": "60+", "l": "معلمة"},
    {"v": "98%", "l": "رضا الطالبات"}
  ]
}'::jsonb),
('footer', '{
  "brand_name": "منصة تفوّق",
  "brand_subtitle": "ثانوية الطالبات",
  "about": "منصة تعليمية تفاعلية مخصصة لطالبات المرحلة الثانوية لتعزيز مهاراتهن في اختبارات التحصيلي والقدرات عبر أدوات حديثة وممتعة.",
  "email": "info@tafawuq.edu.sa",
  "phone": "+966 11 000 0000",
  "address": "المملكة العربية السعودية",
  "copyright": "منصة تفوّق - جميع الحقوق محفوظة | بدعم من وزارة التعليم"
}'::jsonb),
('features_section', '{
  "title": "كل ما تحتاجينه للتفوّق في مكان واحد",
  "subtitle": "أدوات تعليمية حديثة مصممة خصيصاً لطالبات المرحلة الثانوية",
  "eyebrow": "مميزات المنصة"
}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- Add active status to profiles for enable/disable
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
