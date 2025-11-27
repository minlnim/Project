# Initialize RDS Database with test data
# PowerShell version

Write-Host "Initializing Seoul Portal Database..." -ForegroundColor Cyan

# Get RDS endpoint from Terraform output
Set-Location ..\infra\terraform
$DB_ENDPOINT = terraform output -raw db_endpoint
$DB_NAME = "corpportal"
$DB_USER = "portaluser"
$DB_PASSWORD = "SeoulPortal2025!SecureDB#Pass"
Set-Location ..\..\scripts

if ([string]::IsNullOrEmpty($DB_ENDPOINT)) {
    Write-Host "Error: Could not get RDS endpoint from Terraform" -ForegroundColor Red
    exit 1
}

Write-Host "RDS Endpoint: $DB_ENDPOINT" -ForegroundColor Yellow

# Check if psql is installed
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlPath) {
    Write-Host "Error: PostgreSQL client (psql) is not installed" -ForegroundColor Red
    Write-Host "Please install PostgreSQL client tools" -ForegroundColor Yellow
    exit 1
}

# Execute SQL script
Write-Host "Executing initialization script..." -ForegroundColor Cyan
$env:PGPASSWORD = $DB_PASSWORD
psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -f init-database.sql

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Database initialized successfully!" -ForegroundColor Green
    
    # Show employee count
    Write-Host "`nEmployee count:" -ForegroundColor Cyan
    $query = "SELECT COUNT(*) as count FROM employees;"
    $env:PGPASSWORD = $DB_PASSWORD
    psql -h $DB_ENDPOINT -U $DB_USER -d $DB_NAME -c $query
} else {
    Write-Host "❌ Failed to initialize database" -ForegroundColor Red
    exit 1
}

# Clear password from environment
Remove-Item Env:\PGPASSWORD
