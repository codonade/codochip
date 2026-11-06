@echo off
if not exist ".\bin\" mkdir "bin"
odin build "codochip.odin" -file -out:".\bin\codochip.exe"
