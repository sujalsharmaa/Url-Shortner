"use client"

// pages/short/[url].js or app/short/[url]/page.js
import React, { useEffect } from 'react';
import { useRouter } from 'next/navigation';

const RedirectPage = ({params}) => {
  const router = useRouter();
  useEffect(() => {
    if (params) {
      // Perform the redirection logic
      window.location.href = `${process.env.NEXT_PUBLIC_API_URL}/short/${params.url}`;
    }
  }, [params]);

  return (
    <div>
      <p>Redirecting...</p>
    </div>
  );
};

export default RedirectPage;
