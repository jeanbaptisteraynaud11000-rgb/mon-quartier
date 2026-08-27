import { requireAdmin } from '@/lib/requireAdmin';
import PostsAdminList from './PostsAdminList';

export default async function AdminPostsPage() {
  await requireAdmin();
  return <PostsAdminList />;
}

