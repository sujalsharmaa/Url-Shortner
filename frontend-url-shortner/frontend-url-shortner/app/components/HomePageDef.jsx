"use client";
import React from 'react';
import dotenv from "dotenv"
dotenv.config()

const HomePage = () => {
  return (
    <div className="w-full min-h-screen flex justify-center items-center bg-gradient-to-r from-purple-500 via-pink-500 to-blue-500 animate-gradient-x">
      <div className="text-center p-8 backdrop-blur-sm bg-white/20 rounded-xl shadow-lg">
        <h1 className="text-8xl font-extrabold m-2 text-transparent bg-clip-text bg-gradient-to-r from-indigo-600 to-pink-600 animate-pulse">
          Backend will be up on Demand. Currently I cannot AFFORD to run kubernetes Cluster 24/7
          Please contact me on sujalsharma151@gmail.com for any Query.
        </h1>
        <h1 className="text-8xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-violet-600 to-cyan-500 m-5 animate-bounce">
          {process.env.LINE}
        </h1>
        <h2 className="text-5xl text-transparent bg-clip-text bg-gradient-to-r from-blue-500 to-purple-500 m-5 animate-fade-in">
          Signup or login to get started
        </h2>
      </div>
    </div>
  );
};

export default HomePage;
