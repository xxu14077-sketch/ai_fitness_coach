@echo off
echo ==========================================
echo      AI Fitness Coach - Auto Deploy
echo ==========================================
echo.

echo [1/4] Building Flutter Web App...
call flutter build web --release
if %errorlevel% neq 0 (
    echo Build failed!
    pause
    exit /b %errorlevel%
)

echo.
echo [2/4] Updating Deployment Files...
if exist public (
    rmdir /s /q public
)
mkdir public
xcopy /s /e /y build\web\* public\ > nul

echo.
echo [3/4] Pushing to GitHub...
git add public
git commit -m "Deploy: Update web build %date% %time%"
git push origin main

echo.
echo [4/4] Done! Vercel will auto-deploy shortly.
echo ==========================================
pause
