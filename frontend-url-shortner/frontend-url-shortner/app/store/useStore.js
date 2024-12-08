"use client";
import dotenv from "dotenv";
import { create } from "zustand";
import axios from "axios";
import {jwtDecode} from "jwt-decode";

dotenv.config();

// Configure Axios Defaults
axios.defaults.withCredentials = true;
axios.defaults.baseURL = process.env.NEXT_PUBLIC_API_URL; // Base API URL
axios.defaults.headers.common['Content-Type'] = 'application/json';

// JWT Token Expiry Checker
function isTokenExpired(token) {
  try {
    const decodedToken = jwtDecode(token);
    const currentTime = Math.floor(Date.now() / 1000); // Current time in seconds
    console.log("Decoded Token", decodedToken);
    return decodedToken.exp < currentTime; // True if token is expired
  } catch (error) {
    console.log("Error decoding token:", error);
    return true; // Treat as expired if there's an error
  }
}

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
    if (token && !isTokenExpired(token)) {
      set({ token, isAuthenticated: true });
    } else {
      localStorage.removeItem("authToken");
      set({ token: null, isAuthenticated: false });
    }
  },

  startTokenCheck: () => {
    setInterval(() => {
      const token = localStorage.getItem("authToken");
      if (token && isTokenExpired(token)) {
        console.log("Token expired, logging out...");
        useStore.getState().logout(); // Call logout function
      }
    }, 60000); // Check every minute
  },

  login: async (username, password, router) => {
    try {
      const response = await axios.post("/auth/login", {
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
      console.log("Login error", error);
      set({ error: "Login failed. Check your credentials." });
    }
  },

  signup: async (email, password, router) => {
    try {
      const response = await axios.post("/auth/register", {
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
      console.log("Signup error", error);
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
      const response = await axios.get("/auth/getAllUrls", {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      set({ urls: response.data, loading: false });
    } catch (error) {
      console.log("Failed to load URLs", error);
      set({ error: "Failed to load URLs", loading: false });
    }
  },

  createShortUrl: async (originalUrl) => {
    try {
      // Set loading to true
      set({ loading: true });
  
      // Check if the URL already exists
      const isAlreadyExist = useStore.getState().urls.some(
        (item) => originalUrl.toLowerCase() === item.original_url.toLowerCase()
      );
  
      if (isAlreadyExist) {
        // Set an error if URL already exists
        set({
          error: "URL already exists",
          loading: false,
        });
        return; // Exit early
      }
  
      // Get token from the store
      const token = useStore.getState().token;
  
      // Send a POST request to create a short URL
      const response = await axios.post(
        "/auth/url",
        { url: originalUrl },
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      );
  
      // Log the response data for debugging
      console.log(response.data);
  
      // Update the URLs in the state with the new short URL
      set((state) => ({
        urls: [...state.urls, response.data],
        loading: false,
        error: null,
      }));
    } catch (error) {
      // Log the error for debugging
      console.error("Error creating short URL:", error);
  
      // Set an error message in the state
      set({
        error: "Failed to create short URL",
        loading: false,
      });
    }
  },
  
}));

export default useStore;
