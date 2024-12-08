#!/bin/sh

# Create a config.js file that contains runtime environment variables
cat <<EOF > /app/.next/static/runtime-config.js
window.__ENV__ = {
  NEXT_PUBLIC_API_URL: "${NEXT_PUBLIC_API_URL}",
  NEXT_PUBLIC_DOMAIN: "${NEXT_PUBLIC_DOMAIN}"
};
EOF

# Start the Next.js server
exec npm run start -- -p 3001
