"use client";

import { create } from 'zustand';
import axios from 'axios';


//axios.defaults.withCredentials = true

const useStore = create((set) => ({
  // Authentication State
  user: null,
  isAuthenticated: false,
  token: null,

  // URL Data
  urls: [],
  loading: false,
  error: null,

  // Actions
  initializeAuth: () => {
    const token = localStorage.getItem("authToken");
    if (token) {
      set({ token, isAuthenticated: true });
    }
  },

  login: async (username, password, router) => {
    try {
      const url = `${process.env.NEXT_PUBLIC_API_URL}/auth/login`
      console.log(url)
      const response = await axios.post( `${url}` , { 
        username,
        password,
      });
      const token = response.data.token;
      localStorage.setItem("authToken", token);
      
      set({
        user: response.data.user,
        token,
        isAuthenticated: true,
        error: null,
      });
      
      router.push("/Home");
    } catch (error) {
      console.error("Login error", error);
      set({ error: "Login failed. Check your credentials." });
    }
  },

  signup: async (email, password, router) => {
    try {
      const response = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/auth/register`, {
        username: email,
        password,
      });

      set({
        user: response.data.user,
        token: response.data.token,
        isAuthenticated: false,
        error: null,
      });
      router.push("/Login");
    } catch (error) {
      console.error("Signup error", error);
      set({ error: "Signup failed. Check your credentials." });
    }
  },

  logout: (router) => {
    localStorage.removeItem("authToken");

    set({
      user: null,
      token: null,
      isAuthenticated: false,
      error: null,
    });

    router.push("/"); // Redirect to home or login page on logout
  },

  fetchUrls: async () => {
    set({ loading: true });
    try {
      const token = useStore.getState().token;
      const response = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/auth/getAllUrls`, {
        headers: {
          authorization: `Bearer ${token}`
        }
      });
      set({ urls: response.data, loading: false });
    } catch (error) {
      console.log('Failed to load URLs', error);
      set({ error: 'Failed to load URLs', loading: false });
    }
  },
  
  createShortUrl: async (originalUrl) => {
    set({ loading: true });
    try {
        const token = useStore.getState().token; // Ensure the token is retrieved correctly
        const response = await axios.post(
            `${process.env.NEXT_PUBLIC_API_URL}/auth/url`,
            { url: originalUrl },
            {
                headers: {
                    Authorization: `Bearer ${token}`
                }
            }
        );

        console.log(response.data);
        set((state) => ({
            urls: [...state.urls, response.data],
            loading: false,
            error: null,
        }));
    } catch (error) {
        console.error("Error creating short URL:", error);
        set({ error: "Failed to create short URL", loading: false });
    }
},


}));

export default useStore;
