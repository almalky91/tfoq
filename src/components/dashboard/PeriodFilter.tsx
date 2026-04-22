import { CalendarDays } from "lucide-react";

export type Period = "7d" | "30d" | "month";

export const periodLabels: Record<Period, string> = {
  "7d": "آخر 7 أيام",
  "30d": "آخر 30 يوماً",
  "month": "هذا الشهر",
};

export const getPeriodStart = (period: Period): Date => {
  const now = new Date();
  if (period === "7d") {
    const d = new Date(now); d.setDate(now.getDate() - 7); return d;
  }
  if (period === "30d") {
    const d = new Date(now); d.setDate(now.getDate() - 30); return d;
  }
  return new Date(now.getFullYear(), now.getMonth(), 1);
};

export const PeriodFilter = ({ value, onChange }: { value: Period; onChange: (v: Period) => void }) => {
  const options: Period[] = ["7d", "30d", "month"];
  return (
    <div className="flex items-center gap-2 flex-wrap">
      <div className="flex items-center gap-1.5 text-muted-foreground text-sm">
        <CalendarDays className="w-4 h-4" />
        <span className="hidden sm:inline">الفترة:</span>
      </div>
      <div className="inline-flex rounded-xl bg-muted p-1 border border-border/50">
        {options.map((opt) => (
          <button
            key={opt}
            onClick={() => onChange(opt)}
            className={`px-3 py-1.5 text-xs sm:text-sm font-bold rounded-lg transition-all ${
              value === opt
                ? "bg-card text-primary shadow-sm"
                : "text-muted-foreground hover:text-foreground"
            }`}
          >
            {periodLabels[opt]}
          </button>
        ))}
      </div>
    </div>
  );
};
