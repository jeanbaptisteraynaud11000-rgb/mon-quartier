import { requireAdmin } from '@/lib/requireAdmin';
import ReportsList from './ReportsList';

export default async function AdminReportsPage() {
  await requireAdmin();
  return <ReportsList />;
}

