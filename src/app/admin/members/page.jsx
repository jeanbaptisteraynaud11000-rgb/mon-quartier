import { requireAdmin } from '@/lib/requireAdmin';
import MembersAdminList from './MembersAdminList';

export default async function AdminMembersPage() {
  const { quartierId } = await requireAdmin();
  return <MembersAdminList quartierId={quartierId} />;
}

