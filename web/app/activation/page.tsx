'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useOnboardingGuard } from '@/lib/hooks/useOnboardingGuard';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { 
  CheckCircle2, 
  Circle,
  Users,
  Package,
  ShoppingCart,
  Receipt,
  CreditCard,
  ArrowRight,
  Sparkles
} from 'lucide-react';

interface ChecklistItem {
  id: string;
  label: string;
  completed: boolean;
  icon: any;
  description: string;
}

export default function ActivationDashboardPage() {
  const router = useRouter();
  const isReady = useOnboardingGuard();
  const [checklist, setChecklist] = useState<ChecklistItem[]>([
    {
      id: 'add_retailer',
      label: 'Add retailer',
      completed: false,
      icon: Users,
      description: 'Add your first customer to start taking orders'
    },
    {
      id: 'add_product',
      label: 'Add product',
      completed: false,
      icon: Package,
      description: 'Add products to your catalog'
    },
    {
      id: 'place_order',
      label: 'Place order',
      completed: false,
      icon: ShoppingCart,
      description: 'Create your first order with a customer'
    },
    {
      id: 'generate_invoice',
      label: 'Generate invoice',
      completed: false,
      icon: Receipt,
      description: 'Generate a GST-compliant invoice'
    },
    {
      id: 'record_payment',
      label: 'Record payment',
      completed: false,
      icon: CreditCard,
      description: 'Track payment against an order'
    },
  ]);

  const completedCount = checklist.filter(item => item.completed).length;
  const totalCount = checklist.length;
  const progress = Math.round((completedCount / totalCount) * 100);
  const isFullyActivated = completedCount === totalCount;

  // Prevent any render while checking - return null to avoid flick
  if (!isReady) {
    return null;
  }

  const handleCompleteTask = (taskId: string) => {
    if (taskId === 'add_retailer') {
      router.push('/dashboard/retailers?action=add');
    } else if (taskId === 'add_product') {
      router.push('/dashboard/products?action=add');
    } else if (taskId === 'place_order') {
      router.push('/dashboard/orders?action=create');
    } else if (taskId === 'generate_invoice') {
      router.push('/dashboard/invoices?action=generate');
    } else if (taskId === 'record_payment') {
      router.push('/dashboard/payments?action=record');
    }
  };

  return (
    <div className="min-h-screen bg-background-subtle">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 py-8 sm:py-12">
        {/* Header */}
        <div className="text-center mb-8 sm:mb-12">
          <div className="inline-flex items-center justify-center w-16 h-16 sm:w-20 sm:h-20 bg-primary-50 rounded-2xl mb-4 sm:mb-6">
            <Sparkles className="w-8 h-8 sm:w-10 sm:h-10 text-primary" />
          </div>
          <h1 className="text-3xl sm:text-4xl font-bold text-text-primary mb-3 sm:mb-4">
            {isFullyActivated ? '🎉 You\'re All Set!' : 'Almost There!'}
          </h1>
          <p className="text-base sm:text-xl text-text-secondary">
            {isFullyActivated 
              ? 'Your account is fully activated. Start managing your distribution business.'
              : 'Complete a few more steps to fully activate your account'}
          </p>
        </div>

        {/* Progress Card */}
        <Card className="p-6 sm:p-8 mb-6 sm:mb-8">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 sm:gap-0 mb-6">
            <div>
              <h2 className="text-xl sm:text-2xl font-bold text-text-primary mb-2">
                Activation Progress
              </h2>
              <p className="text-text-secondary">
                {completedCount} of {totalCount} steps completed
              </p>
            </div>
            <div className="text-right sm:text-center">
              <div className="text-3xl sm:text-4xl font-bold text-primary mb-1">{progress}%</div>
              {isFullyActivated && (
                <Badge variant="success">All Complete</Badge>
              )}
            </div>
          </div>

          {/* Progress Bar */}
          <div className="h-3 bg-background rounded-full overflow-hidden">
            <div 
              className="h-full bg-primary transition-all duration-500 rounded-full"
              style={{ width: `${progress}%` }}
            />
          </div>
        </Card>

        {/* Checklist */}
        <div className="space-y-3 sm:space-y-4">
          {checklist.map((item) => {
            const Icon = item.icon;
            return (
              <Card key={item.id} className="p-4 sm:p-6 hover:shadow-md transition-shadow">
                <div className="flex flex-col sm:flex-row items-start sm:items-center gap-4 sm:gap-0">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <div className={`flex-shrink-0 ${item.completed ? 'text-success' : 'text-text-secondary'}`}>
                        {item.completed ? (
                          <CheckCircle2 className="w-6 h-6" />
                        ) : (
                          <Circle className="w-6 h-6" />
                        )}
                      </div>
                      <h3 className="text-base sm:text-lg font-semibold text-text-primary">
                        {item.label}
                      </h3>
                    </div>
                    <p className="text-sm text-text-secondary ml-9 mb-3 sm:mb-0">
                      {item.description}
                    </p>
                  </div>
                  <Button
                    onClick={() => handleCompleteTask(item.id)}
                    disabled={item.completed}
                    className="w-full sm:w-auto"
                    variant={item.completed ? 'outline' : 'default'}
                  >
                    {item.completed ? 'Completed' : 'Complete'} 
                    {!item.completed && <ArrowRight className="ml-2 w-4 h-4" />}
                  </Button>
                </div>
              </Card>
            );
          })}
        </div>

        {/* Call to action */}
        <div className="mt-8 sm:mt-12 flex flex-col sm:flex-row gap-4 justify-center items-center">
          {isFullyActivated && (
            <Button onClick={() => router.push('/dashboard')} className="px-8 py-3 text-base">
              Go to Dashboard
              <ArrowRight className="ml-2 w-4 h-4" />
            </Button>
          )}
          <Button 
            onClick={() => router.push('/dashboard')} 
            variant="outline"
            className="px-8 py-3 text-base"
          >
            Skip for now
          </Button>
        </div>
      </div>
    </div>
  );
}
