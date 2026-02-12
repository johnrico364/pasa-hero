Write-Host "Starting PasaHero Server..." -ForegroundColor Green
Write-Host ""
Write-Host "Make sure you have configured .env file with EMAIL_USER and EMAIL_APP_PASSWORD" -ForegroundColor Yellow
Write-Host ""
Set-Location $PSScriptRoot
npm run dev
