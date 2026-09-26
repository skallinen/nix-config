#!/bin/sh
# utm-escape: the second half of the Control+Shift+Escape escape hatch (Karabiner rule
# "Control+Shift+Escape -> escape from UTM capture" in darwin-configuration.nix).
#
# Karabiner has already activated Finder, which takes focus from UTM; its VM window
# resigns main and releases the pointer and the keyboard. This script runs inside
# Terminal because Terminal holds the Accessibility grant that System Events needs; it
# lists every sheet or dialog UTM has open, with its text and buttons, and offers to
# click Cancel. It never clicks any other button: OK on UTM's quit sheet kills the VM.
#
# Why this exists: utm-arch wiki/utm-input-and-keyboard.md, "Captured behind a sheet".

report=$(/usr/bin/osascript <<'EOF'
on joinList(xs, sep)
  set AppleScript's text item delimiters to sep
  set s to xs as text
  set AppleScript's text item delimiters to ""
  return s
end joinList

tell application "System Events"
  if not (exists process "UTM") then return "NONE" & linefeed & "UTM is not running."
  set out to ""
  set cancelTarget to ""
  tell process "UTM"
    repeat with w in windows
      set wname to ""
      try
        set wname to name of w
      end try
      set dialogs to {}
      try
        set dialogs to sheets of w
      end try
      try
        if subrole of w is in {"AXDialog", "AXSystemDialog"} then set end of dialogs to w
      end try
      repeat with d in dialogs
        set texts to {}
        try
          set texts to value of static texts of d
        end try
        set btns to {}
        try
          repeat with b in (name of buttons of d)
            if b is not missing value then set end of btns to (b as text)
          end repeat
        end try
        if btns is {} then set texts to missing value
        if texts is not missing value then
          set out to out & "Window: " & wname & linefeed
          set out to out & "  Text: " & my joinList(texts, " / ") & linefeed
          set out to out & "  Buttons: " & my joinList(btns, ", ") & linefeed
          if cancelTarget is "" and btns contains "Cancel" then set cancelTarget to wname
        end if
      end repeat
    end repeat
  end tell
  if out is "" then return "NONE" & linefeed & "UTM has no sheet or dialog open."
  return "CANCEL:" & cancelTarget & linefeed & out
end tell
EOF
)

head=$(printf '%s\n' "$report" | head -n 1)
printf '%s\n' "$report" | tail -n +2
echo

case "$head" in
  NONE)
    echo "Pointer and keyboard are back with macOS. Click the VM window to capture again."
    echo "A sheet on a full screen VM lives in that Space and is not listed here: go there,"
    echo "and press Escape on it (Escape is Cancel; Return is OK, which kills the VM on a quit sheet)."
    exit 0 ;;
  "CANCEL:")
    echo "No Cancel button found. Answer the dialog by hand; UTM will not capture while it is open."
    exit 0 ;;
esac

target=${head#CANCEL:}
echo "Type c and Return to click Cancel on the sheet of \"$target\" (Cancel keeps the VM running)."
echo "Anything else leaves it; UTM does not capture while a sheet is open, so you can click"
echo "its window and answer yourself (Escape is Cancel, Return is the default button)."
printf '> '
read -r answer
if [ "$answer" = c ]; then
  UTM_ESCAPE_TARGET="$target" /usr/bin/osascript -e '
    set t to system attribute "UTM_ESCAPE_TARGET"
    tell application "System Events" to tell process "UTM"
      click button "Cancel" of sheet 1 of window t
    end tell' && echo "Clicked Cancel."
fi
