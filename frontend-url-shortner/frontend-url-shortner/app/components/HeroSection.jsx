"use client";
import React, { useState } from 'react';
import useStore from '../store/useStore';

const HeroSection = ({ data }) => {
  const [originalUrl, setOriginalUrl] = useState('');
  const { createShortUrl, urls, loading, error } = useStore();

  // Pagination setup
  const [currentPage, setCurrentPage] = useState(1);
  const rowsPerPage = 5;

  // Calculate pagination values
  const lastRowIndex = currentPage * rowsPerPage;
  const firstRowIndex = lastRowIndex - rowsPerPage;
  const currentRows = data.slice(firstRowIndex, lastRowIndex);

  // Pagination controls
  const totalPages = Math.ceil(data.length / rowsPerPage);
  const goToNextPage = () => setCurrentPage((page) => Math.min(page + 1, totalPages));
  const goToPreviousPage = () => setCurrentPage((page) => Math.max(page - 1, 1));

  const handleSubmit = async (e) => {
    e.preventDefault();
    await createShortUrl(originalUrl);
    setOriginalUrl('');
  };

  return (
    <div className="p-8 border-2 bg-gradient-to-r from-blue-100 to-purple-100 rounded-xl shadow-lg">
      <div className="m-6">
        <section className="flex justify-center mb-8">
          <form onSubmit={handleSubmit} className="flex w-full max-w-md">
            <input
              type="text"
              className="flex-grow p-2 text-black rounded-l-md border-2 border-purple-300 focus:outline-none focus:border-purple-500"
              value={originalUrl}
              onChange={(e) => setOriginalUrl(e.target.value)}
              placeholder="Enter URL to shorten"
            />
            <button
              type="submit"
              className="p-2 bg-purple-600 text-white font-bold rounded-r-md hover:bg-purple-700 transition-colors duration-300"
              disabled={loading}
            >
              {loading ? 'Shortening...' : 'Shorten'}
            </button>
          </form>
        </section>
        {error && <p className="text-red-500 text-center">{error}</p>}
      </div>

      <div className="overflow-x-auto">
        <table className="w-full rounded-md shadow-md overflow-hidden border-collapse bg-white">
          <thead>
            <tr className="bg-gradient-to-r from-purple-600 to-blue-600 text-white">
              <th className="py-4 px-6 text-left">Original URL</th>
              <th className="py-4 px-6 text-left">Short URL</th>
            </tr>
          </thead>
          <tbody>
            {currentRows.map((url, index) => (
              <tr key={index} className="hover:bg-purple-100 transition duration-200">
                <td
                  className="py-4 px-6 border-b text-black border-gray-300 max-w-xs overflow-hidden text-ellipsis whitespace-nowrap"
                  title={url.original_url}
                >
                  {url.original_url}
                </td>
                <td className="py-4 px-6 border-b border-gray-300 text-blue-800 max-w-xs overflow-hidden text-ellipsis whitespace-nowrap">
                  <a
                    className="bg-blue-200 p-1 rounded-md inline-block hover:bg-blue-300 transition-colors duration-300"
                    href={`${process.env.NEXT_PUBLIC_DOMAIN}/short/${url.short_url}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    title={`${process.env.NEXT_PUBLIC_DOMAIN}/short/${url.short_url}`}
                  >
                    {`${process.env.NEXT_PUBLIC_DOMAIN}/short/${url.short_url}`}
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="flex justify-between items-center mt-6">
        <button
          onClick={goToPreviousPage}
          disabled={currentPage === 1}
          className="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 transition-colors duration-300 disabled:opacity-50"
        >
          Previous
        </button>
        <span className="text-gray-600">Page {currentPage} of {totalPages}</span>
        <button
          onClick={goToNextPage}
          disabled={currentPage === totalPages}
          className="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 transition-colors duration-300 disabled:opacity-50"
        >
          Next
        </button>
      </div>
    </div>
  );
};

export default HeroSection;
