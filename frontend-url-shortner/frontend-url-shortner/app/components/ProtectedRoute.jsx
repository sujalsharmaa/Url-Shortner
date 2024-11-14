import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import useStore from '../store/useStore';

const ProtectedRoute = ({ children }) => {
  const router = useRouter();
  const { isAuthenticated } = useStore();

  useEffect(() => {
    if (!isAuthenticated) {
      router.push('/');
    }
  }, [isAuthenticated, router]);

  if (!isAuthenticated) {
    return null; // Optionally, show a loading indicator here
  }

  return children;
};

export default ProtectedRoute;
