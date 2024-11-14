"use client"
import Link from 'next/link';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import useStore from '../store/useStore'; // Adjust the path based on where your Zustand store is located

export default function Navbar() {
  const [menuOpen, setMenuOpen] = useState(false);
  const router = useRouter();

  // Access isAuthenticated and logout function from Zustand store
  const isAuthenticated = useStore((state) => state.isAuthenticated);
  const logout = useStore((state) => state.logout);

  const handleSignupClick = () => {
    router.push('/Signup');
  };

  const handleLoginClick = () => {
    router.push('/Login');
  };

  const handleLogoutClick = () => {
    logout(); // Call logout function from Zustand store
    router.push('/'); // Redirect to home page after logout
  };

  return (
    <nav className="bg-transparent shadow-lg">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex items-center">
            {/* Logo */}
            <Link href="/" passHref>
              <span className="text-2xl font-bold text-orange-600">MyLogo</span>
            </Link>

            {/* Additional Navigation Links can go here */}
          </div>

          {/* Search Bar and Buttons */}
          <div className="flex items-center space-x-4">
            {!isAuthenticated ? (
              <>
                <button
                  onClick={handleSignupClick}
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-500"
                >
                  Sign Up
                </button>

                <button
                  onClick={handleLoginClick}
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-500"
                >
                  Login
                </button>
              </>
            ) : (
              <button
                onClick={handleLogoutClick}
                className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-500"
              >
                Logout
              </button>
            )}

            {/* Mobile Menu Button */}
            <button
              onClick={() => setMenuOpen(!menuOpen)}
              className="md:hidden focus:outline-none text-gray-700"
            >
              <svg
                className="w-6 h-6"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4 6h16M4 12h16m-7 6h7"
                />
              </svg>
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Menu */}
      {menuOpen && (
        <div className="md:hidden">
          <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3">
            <Link href="/" passHref>
              <span className="block px-3 py-2 rounded-md text-base font-medium text-gray-700 hover:bg-gray-200">Home</span>
            </Link>
            {!isAuthenticated ? (
              <>
                <Link href="/signup" passHref>
                  <span className="block px-3 py-2 rounded-md text-base font-medium text-gray-700 hover:bg-gray-200">Sign Up</span>
                </Link>
                <Link href="/login" passHref>
                  <span className="block px-3 py-2 rounded-md text-base font-medium text-gray-700 hover:bg-gray-200">Login</span>
                </Link>
              </>
            ) : (
              <button
                onClick={handleLogoutClick}
                className="block px-3 py-2 rounded-md text-base font-medium text-gray-700 hover:bg-gray-200 w-full text-left"
              >
                Logout
              </button>
            )}
          </div>
        </div>
      )}
    </nav>
  );
}
