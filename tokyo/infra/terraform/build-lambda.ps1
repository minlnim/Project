# Lambda 배포 패키지 생성 스크립트 (Windows)

$lambdaDir = "lambda\db-init"
$packageDir = "$lambdaDir\package"
$outputZip = "lambda\db-init.zip"

# 기존 패키지 제거
if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}
if (Test-Path $outputZip) {
    Remove-Item -Force $outputZip
}

# 패키지 디렉토리 생성
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

# pymysql 설치
Write-Host "Installing pymysql..."
pip install -t $packageDir pymysql

# 소스 파일 복사
Write-Host "Copying source files..."
Copy-Item "$lambdaDir\index.py" "$packageDir\"

# ZIP 파일 생성
Write-Host "Creating ZIP file..."
Compress-Archive -Path "$packageDir\*" -DestinationPath $outputZip -Force

# 정리
Remove-Item -Recurse -Force $packageDir

Write-Host "Lambda deployment package created: $outputZip"
