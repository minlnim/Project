#!/bin/sh
# env.sh - Generate environment configuration for frontend

cat > /usr/share/nginx/html/env-config.js << EOF
window.API_GATEWAY_URL = "${API_GATEWAY_URL:-https://tnuq8drlck.execute-api.ap-northeast-2.amazonaws.com}";
window.COGNITO_REGION = "${COGNITO_REGION:-ap-northeast-2}";
window.COGNITO_USER_POOL_ID = "${COGNITO_USER_POOL_ID:-ap-northeast-2_e5tqVVahP}";
window.COGNITO_CLIENT_ID = "${COGNITO_CLIENT_ID:-7o2taqnfu90tjutsi3ibm7uqtn}";
EOF

echo "Environment configuration generated"
cat /usr/share/nginx/html/env-config.js
