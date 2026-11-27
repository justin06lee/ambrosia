# Ambrosia's Clear Light profile for Konsole, after macOS 27 Terminal's profile of that
# name: 120 by 30, the fixed-width font at a Mac's 12 points (9 here: the
# session's points are a third larger), a gray block that doesn't blink, a little
# room around the text, the title a Mac gives a window (user, then program).
# konsolerc picks this one while the system is in Light.
[Appearance]
BoldIntense=true
ColorScheme=ClearLight
Font=JetBrains Mono,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
LineSpacing=0
UseFontLineChararacters=false

[Cursor Options]
CursorShape=0
CustomCursorColor=145,145,145
CustomCursorTextColor=255,255,255
UseCustomCursorColor=true

[General]
LocalTabTitleFormat=%u — %n
Name=Clear Light
Parent=FALLBACK/
RemoteTabTitleFormat=%u@%h — %n
TerminalCenter=false
TerminalColumns=120
TerminalMargin=8
TerminalRows=30

[Keyboard]
KeyBindings=ambrosia

[Terminal Features]
BlinkingCursorEnabled=false
