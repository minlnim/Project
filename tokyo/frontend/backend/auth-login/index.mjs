import { CognitoIdentityProviderClient, AdminInitiateAuthCommand } from "@aws-sdk/client-cognito-identity-provider";
import { RDSDataClient, ExecuteStatementCommand } from "@aws-sdk/client-rds-data";

const cognito = new CognitoIdentityProviderClient({});
const rds = new RDSDataClient({});
const { USERPOOL_ID, CLIENT_ID, DB_ARN, SECRET_ARN, DB_NAME } = process.env;

export const handler = async (event) => {
  try{
    const { username, password } = JSON.parse(event.body || "{}");
    if(!username || !password){
      return { statusCode: 400, body: "username/password required" };
    }
    const sql = `SELECT employee_id, username, name, department, title, email FROM employees WHERE username = :u`;
    const resp = await rds.send(new ExecuteStatementCommand({
      resourceArn: DB_ARN, secretArn: SECRET_ARN, database: DB_NAME,
      sql, parameters: [{ name: "u", value: { stringValue: username } }]
    }));
    if(!resp.records || resp.records.length === 0){
      return { statusCode: 401, body: "Not registered employee" };
    }
    const cols = resp.columnMetadata.map(c=>c.name);
    const emp = {};
    resp.records[0].forEach((cell, i)=>{ emp[cols[i]] = Object.values(cell)[0]; });
    const auth = await cognito.send(new AdminInitiateAuthCommand({
      UserPoolId: USERPOOL_ID,
      ClientId: CLIENT_ID,
      AuthFlow: "ADMIN_USER_PASSWORD_AUTH",
      AuthParameters: { USERNAME: username, PASSWORD: password }
    }));
    const tokens = auth.AuthenticationResult || {};
    const body = {
      idToken: tokens.IdToken,
      accessToken: tokens.AccessToken,
      refreshToken: tokens.RefreshToken,
      employee: {
        employee_id: emp.employee_id,
        name: emp.name,
        department: emp.department,
        title: emp.title,
        email: emp.email,
        username: emp.username
      }
    };
    return { statusCode: 200, headers: { "Content-Type":"application/json" }, body: JSON.stringify(body) };
  }catch(err){
    return { statusCode: 401, body: "Cognito login failed" };
  }
};