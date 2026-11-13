@echo off
rem Build and run the Quiz & Examination Management System (Windows).
rem   run.bat           compile and start the application (data in .\data)
rem   run.bat --demo    start and create demo records if the data folder is empty
rem   run.bat test      compile and run the automated tests
setlocal
cd /d "%~dp0"
if exist out rmdir /s /q out
mkdir out
dir /s /b src\*.java > out\sources.txt
if "%1"=="test" dir /s /b test\*.java >> out\sources.txt
javac --release 17 -encoding UTF-8 -d out @out\sources.txt || exit /b 1
if "%1"=="test" (
  java -cp out tests.TestRunner
) else (
  java -cp out main.Main %*
)
