@IF EXIST "%~dp0\node.exe" (
  appveyor-retry "%~dp0\node.exe"  "%~dp0\bootstrap" %*
) ELSE (
  appveyor-retry node  "%~dp0\bootstrap" %*
)
