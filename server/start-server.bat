@echo off
echo Starting PasaHero Server...
echo.
echo Make sure you have configured .env file with EMAIL_USER and EMAIL_APP_PASSWORD
echo.
cd /d %~dp0
npm run dev
