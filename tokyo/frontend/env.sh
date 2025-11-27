#!/bin/sh
# env.sh - Generate environment configuration for frontend

cat > /usr/share/nginx/html/env-config.js << EOF
window.API_GATEWAY_URL = "${API_GATEWAY_URL:-https://your-api-id.execute-api.ap-northeast-1.amazonaws.com}";
window.COGNITO_REGION = "${COGNITO_REGION:-ap-northeast-1}";
window.COGNITO_USER_POOL_ID = "${COGNITO_USER_POOL_ID:-ap-northeast-1_XXXXXXXXX}";
window.COGNITO_CLIENT_ID = "${COGNITO_CLIENT_ID:-XXXXXXXXXXXXXXXXXXXXXXXXXX}";
EOF

echo "Environment configuration generated"
cat /usr/share/nginx/html/env-config.js
