// نظام حفظ آمن للإجابات مع:
// - تكرار محاولات بفترات متزايدة (exponential backoff)
// - قائمة انتظار محلية (offline queue) في localStorage
// - منع التكرار عبر مفاتيح فريدة
// - مزامنة تلقائية عند عودة الاتصال

import { supabase } from "@/integrations/supabase/client";

const STORAGE_KEY = "tfoq_pending_answers_v1";
const MAX_RETRIES = 3;
const BASE_DELAY_MS = 800;

export type PendingAnswer = {
  client_id: string; // مفتاح فريد لمنع التكرار
  student_id: string;
  question_id: string;
  selected_option: string;
  is_correct: boolean;
  points_earned: number;
  attempted_at: string;
};

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const readQueue = (): PendingAnswer[] => {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
  } catch {
    return [];
  }
};

const writeQueue = (q: PendingAnswer[]) => {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(q));
  } catch {
    // تجاهل أخطاء التخزين (مثل وضع التصفح الخاص)
  }
};

const removeFromQueue = (clientId: string) => {
  writeQueue(readQueue().filter((a) => a.client_id !== clientId));
};

const enqueue = (a: PendingAnswer) => {
  const q = readQueue();
  if (q.some((x) => x.client_id === a.client_id)) return;
  q.push(a);
  writeQueue(q);
};

const insertOnce = async (a: PendingAnswer): Promise<boolean> => {
  // ملاحظة: client_id يُستخدم محلياً فقط لمنع تكرار الإرسال من نفس الجهاز
  const { error } = await supabase.from("quiz_attempts").insert({
    student_id: a.student_id,
    question_id: a.question_id,
    selected_option: a.selected_option,
    is_correct: a.is_correct,
    points_earned: a.points_earned,
  });
  return !error;
};

/**
 * يحفظ إجابة الطالبة مع كل الاحتياطات.
 * - يضع نسخة في localStorage فوراً
 * - يحاول الإرسال مع backoff
 * - عند الفشل يبقى في القائمة للمزامنة لاحقاً
 * - يُرجع true إذا حُفظت محلياً (دائماً) — الحفظ على الخادم قد يتأخر
 */
export const saveAnswer = async (a: Omit<PendingAnswer, "client_id" | "attempted_at"> & { client_id?: string }) => {
  const payload: PendingAnswer = {
    client_id: a.client_id ?? crypto.randomUUID(),
    student_id: a.student_id,
    question_id: a.question_id,
    selected_option: a.selected_option,
    is_correct: a.is_correct,
    points_earned: a.points_earned,
    attempted_at: new Date().toISOString(),
  };

  enqueue(payload);

  // محاولة فورية مع backoff
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    if (!navigator.onLine) break;
    const ok = await insertOnce(payload);
    if (ok) {
      removeFromQueue(payload.client_id);
      return { saved: true, queued: false };
    }
    await sleep(BASE_DELAY_MS * Math.pow(2, attempt) + Math.random() * 200);
  }

  // الإجابة لا تزال في القائمة، ستُرسَل تلقائياً
  return { saved: false, queued: true };
};

/**
 * مزامنة كل الإجابات المعلّقة. تُستدعى عند:
 * - تحميل الصفحة
 * - عودة الاتصال بالإنترنت
 */
export const flushQueue = async () => {
  const q = readQueue();
  if (q.length === 0) return { flushed: 0, remaining: 0 };

  let flushed = 0;
  for (const a of q) {
    if (!navigator.onLine) break;
    const ok = await insertOnce(a);
    if (ok) {
      removeFromQueue(a.client_id);
      flushed++;
    }
  }
  return { flushed, remaining: readQueue().length };
};

export const getQueueSize = () => readQueue().length;

// مزامنة تلقائية عند عودة الاتصال
if (typeof window !== "undefined") {
  window.addEventListener("online", () => {
    void flushQueue();
  });
}
