#!/bin/sh
# env.sh - Generate environment configuration for frontend

cat > /usr/share/nginx/html/env-config.js << EOF
window.API_GATEWAY_URL = "${API_GATEWAY_URL:-https://qfxxv3hll3.execute-api.ap-northeast-2.amazonaws.com}";
window.COGNITO_REGION = "${COGNITO_REGION:-ap-northeast-2}";
window.COGNITO_USER_POOL_ID = "${COGNITO_USER_POOL_ID:-ap-northeast-2_DCWcuUQjO}";
window.COGNITO_CLIENT_ID = "${COGNITO_CLIENT_ID:-5l8mhakqhkt7679noep6k5vu89}";
EOF

echo "Environment configuration generated"
cat /usr/share/nginx/html/env-config.js
