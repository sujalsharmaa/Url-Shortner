/** @type {import('next').NextConfig} */
const nextConfig = {
    reactStrictMode: true,
  
    // Define environment variables to be accessible in the frontend
    env: {
      NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL,
      NEXT_PUBLIC_DOMAIN: process.env.NEXT_PUBLIC_DOMAIN,
    },
  };
  
  export default nextConfig;
  