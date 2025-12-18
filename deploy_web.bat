@echo off
echo ==========================================
echo      AI Fitness Coach - Auto Deploy
echo ==========================================
echo.

echo [1/3] Building Flutter Web App...
call flutter build web --release
if %errorlevel% neq 0 (
    echo Build failed!
    pause
    exit /b %errorlevel%
)

echo.
echo [2/3] Preparing Files for Root Deployment...
:: 复制构建产物到根目录，确保 Vercel 能直接读取
xcopy /s /e /y build\web\* . > nul

echo.
echo [3/3] Pushing to GitHub...
git add .
git commit -m "Deploy: Update web build %date% %time%"
git push origin main

echo.
echo [SUCCESS] Done! Vercel will auto-deploy shortly.
echo ==========================================
pause
