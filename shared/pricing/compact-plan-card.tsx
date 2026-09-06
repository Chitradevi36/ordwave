type CompactPlanAction = JSX.Element | string | number | null | undefined;

type CompactPlanCardProps = {
  badge: string;
  title: string;
  subtitle: string;
  price: string;
  priceSuffix?: string | null;
  helperText?: string | null;
  limits: string[];
  features: string[];
  featured?: boolean;
  selected?: boolean;
  onSelect?: () => void;
  action: CompactPlanAction;
};

export function CompactPlanCard({
  badge,
  title,
  subtitle,
  price,
  priceSuffix,
  helperText,
  limits,
  features,
  featured = false,
  selected = false,
  onSelect,
  action,
}: CompactPlanCardProps) {
  return (
    <div
      onClick={onSelect}
      className={`relative flex h-full flex-col gap-4 overflow-visible rounded-[24px] border bg-white p-5 transition-all ${
        featured
          ? "border-[#1B4332] bg-[linear-gradient(180deg,#F7FBF9_0%,#FFFFFF_62%)] shadow-[0_18px_44px_rgba(27,67,50,0.14)]"
          : selected
            ? "border-[#9CCFB1] bg-[#FBFDFC] shadow-[0_14px_34px_rgba(15,23,42,0.08)]"
            : "border-[#DCE5DD] shadow-[0_14px_34px_rgba(15,23,42,0.06)]"
      } ${onSelect ? "cursor-pointer hover:-translate-y-0.5 hover:border-[#BCD7C7] hover:shadow-[0_18px_42px_rgba(15,23,42,0.09)]" : ""}`}
    >
      {featured && (
        <>
          <div className="absolute inset-x-0 top-0 h-1.5 rounded-t-[24px] bg-[linear-gradient(90deg,#1B4332_0%,#52B788_100%)]" />
          <div className="absolute -top-3 right-4 z-10">
            <span className="rounded-full bg-[#1B4332] px-3 py-1 text-xs font-semibold text-white shadow-[0_10px_20px_rgba(27,67,50,0.22)]">
              {badge}
            </span>
          </div>
        </>
      )}

      {!featured && (
        <div>
          <span className="inline-flex rounded-full border border-[#E2E8F0] bg-[#F8FAF8] px-3 py-1 text-xs font-medium text-[#475569]">
            {badge}
          </span>
        </div>
      )}

      <div className="space-y-1 border-b border-[#EEF2F6] pb-3">
        <h3 className="text-[1.7rem] font-semibold tracking-tight text-[#0F172A]">{title}</h3>
        <p className="text-sm text-[#64748B]">{subtitle}</p>
      </div>

      <div className="space-y-2 border-b border-[#EEF2F6] pb-4">
        <div className="flex items-end gap-1.5">
          <span className="text-4xl font-bold tracking-tight text-[#0F172A]">{price}</span>
          {priceSuffix && <span className="pb-1 text-sm font-medium text-[#64748B]">{priceSuffix}</span>}
        </div>
        {helperText && <p className="text-xs font-medium text-[#64748B]">{helperText}</p>}
      </div>

      <div className="rounded-2xl bg-[#F8FAF8] px-3.5 py-3 text-sm font-medium leading-6 text-[#475569]">
        {limits.join(" • ")}
      </div>

      <ul className="flex-1 space-y-2 text-sm text-[#475569]">
        {features.map((feature) => (
          <li key={feature} className="flex items-start gap-2.5">
            <span className={`mt-[3px] inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[11px] font-bold ${
              featured ? "bg-[#1B4332] text-white" : "bg-[#EFF7F2] text-[#1B4332]"
            }`}>
              ✓
            </span>
            <span>{feature}</span>
          </li>
        ))}
      </ul>

      <div className="mt-auto border-t border-[#EEF2F6] pt-4">{action}</div>
    </div>
  );
}
