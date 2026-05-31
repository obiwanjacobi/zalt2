# installs dependent tools for the CPU project

# WINDOWS

# May fail: Go to 
#   -> Local Security Policy 
#   -> Local Policies (folder)
#   -> Security Options  (folder)
#   -> "User Account Control: Only elevate executables that are signed and validated" 
#   and set to Disabled, then retry.
#   Revert setting to Enabled when done.
winget install doxygen
