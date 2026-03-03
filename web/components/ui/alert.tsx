import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";
import { HTMLAttributes } from "react";

const alertVariants = cva(
  "relative w-full rounded-lg border p-4",
  {
    variants: {
      variant: {
        default: "bg-background-subtle border-border text-text-primary",
        success: "bg-green-50 border-accent text-[#1B4332]",
        warning: "bg-yellow-50 border-warning text-yellow-900",
        danger: "bg-red-50 border-danger text-red-900",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
);

export interface AlertProps
  extends HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof alertVariants> {
  title?: string;
}

function Alert({ className, variant, title, children, ...props }: AlertProps) {
  return (
    <div className={cn(alertVariants({ variant }), className)} {...props}>
      {title && <h5 className="mb-1 font-semibold">{title}</h5>}
      <div className="text-sm">{children}</div>
    </div>
  );
}

export { Alert, alertVariants };
