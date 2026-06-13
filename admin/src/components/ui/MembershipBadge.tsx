import { cn, MEMBERSHIP_CONFIG } from '@/lib/utils';

interface Props {
  type: string;
  size?: 'xs' | 'sm' | 'md';
  showIcon?: boolean;
}

export function MembershipBadge({ type, size = 'sm', showIcon = true }: Props) {
  const config = MEMBERSHIP_CONFIG[type as keyof typeof MEMBERSHIP_CONFIG] || MEMBERSHIP_CONFIG.new;

  const sizeClasses = {
    xs: 'text-xs px-1.5 py-0.5',
    sm: 'text-xs px-2 py-1',
    md: 'text-sm px-2.5 py-1',
  };

  return (
    <span className={cn('inline-flex items-center gap-1 rounded-full font-medium', config.color, sizeClasses[size])}>
      {showIcon && <span className="text-xs">{config.icon}</span>}
      {config.label}
    </span>
  );
}
