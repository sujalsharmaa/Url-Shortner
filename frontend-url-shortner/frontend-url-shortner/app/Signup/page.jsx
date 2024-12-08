"use client";
import React, { useState } from "react";
import useStore from "../store/useStore"; // Import Zustand store
import { useRouter } from "next/navigation";
import { FaSpinner } from "react-icons/fa"; // Add this if you're using a spinner icon

const SignupForm = () => {
  const [formData, setFormData] = useState({
    email: "",
    password: "",
  });

  const signup = useStore((state) => state.signup);
  const loading = useStore((state) => state.loading); // Access loading state
  const error = useStore((state) => state.error); // Access error state
  const router = useRouter();

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    await signup(formData.email, formData.password, router);
  };

  return (
    <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-orange-600 to-orange-950">
      <div className="w-full max-w-md p-8 space-y-6 bg-white rounded shadow-md">
        <h2 className="text-2xl font-bold text-center text-gray-800">Sign Up</h2>
        {error && <p className="text-red-600 text-center">{error}</p>}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-gray-700">Email</label>
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleChange}
              className="w-full px-3 py-2 mt-1 border border-gray-300 rounded focus:outline-none focus:ring focus:ring-indigo-200 text-black"
              required
            />
          </div>
          <div>
            <label className="block text-gray-700">Password</label>
            <input
              type="password"
              name="password"
              value={formData.password}
              onChange={handleChange}
              className="w-full px-3 py-2 mt-1 border border-gray-300 rounded focus:outline-none focus:ring focus:ring-indigo-200 text-black"
              required
            />
          </div>
          <button
            type="submit"
            className="w-full py-2 font-bold text-white bg-indigo-600 rounded hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-opacity-75 flex items-center justify-center"
            disabled={loading}
          >
            {loading ? (
              <>
                <FaSpinner className="animate-spin mr-2" /> Signing up...
              </>
            ) : (
              'Sign Up'
            )}
          </button>
          <button
            type="button"
            onClick={() => router.replace("/Login")}
            className="w-full py-2 font-bold text-white bg-pink-900 rounded hover:bg-pink-800 focus:outline-none focus:ring-2 focus:ring-pink-600 focus:ring-opacity-75"
          >
            Login
          </button>
        </form>
      </div>
    </div>
  );
};

export default SignupForm;
