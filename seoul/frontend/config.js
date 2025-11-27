// Configuration loaded from environment variables only
export const CONFIG = {
  API_BASE: window.API_GATEWAY_URL,
  COGNITO_REGION: window.COGNITO_REGION,
  COGNITO_USER_POOL_ID: window.COGNITO_USER_POOL_ID,
  COGNITO_CLIENT_ID: window.COGNITO_CLIENT_ID
};
