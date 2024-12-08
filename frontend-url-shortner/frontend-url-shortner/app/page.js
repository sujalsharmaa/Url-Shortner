"use client"

import { useEffect } from 'react';
import useStore from './store/useStore';
import { useRouter } from 'next/navigation';
import Navbar from './components/Navbar';
import HomePage from './components/HomePageDef';

export default function HomePageNew() {
  const router = useRouter();
  const { initializeAuth, isAuthenticated } = useStore();

  useEffect(() => {
    initializeAuth();
  }, []);

  useEffect(() => {
    if (isAuthenticated) {
      router.push("/Home");
    }
  }, [isAuthenticated, router]);

  return (
    <div>
      <Navbar/>
      <HomePage/>
    </div>
  );
}
