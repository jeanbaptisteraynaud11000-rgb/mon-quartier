/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        // Autorise les images stockées dans Supabase Storage (buckets avatars/posts).
        // Remplace <PROJECT_REF> par la référence de ton projet Supabase une fois créé,
        // ou laisse générique si tu préfères filtrer plus tard.
        protocol: 'https',
        hostname: '*.supabase.co',
        pathname: '/storage/v1/object/public/**',
      },
    ],
  },
};

module.exports = nextConfig;

