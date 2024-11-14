"use client"

import React, { useEffect } from 'react';
import ProtectedRoute from '../components/ProtectedRoute';
import HeroSection from '../components/HeroSection';
import Navbar from '../components/Navbar';
import useStore from '../store/useStore';

const urlData = [
    { original_url: 'https://example.com/long-url-1', short_url: 'https://short.ly/1' },
    // Additional URL data as needed
];

const Home = () => {
  // Destructure `fetchUrls` and any other state/actions you need
  const { fetchUrls, urls } = useStore();

  useEffect(() => {
    fetchUrls(); // Call the action to load URLs when the component mounts
  }, []);

  return (
    <div>
      <Navbar />
      <ProtectedRoute>
        <HeroSection data={urls.length > 0 ? urls : urlData} />
      </ProtectedRoute>
    </div>
  );
};

export default Home;
