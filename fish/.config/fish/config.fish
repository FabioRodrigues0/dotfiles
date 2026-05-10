if status is-interactive
    # Commands to run in interactive sessions can go here
end
fish_add_path ~/.local/bin
fish_add_path ~/.cargo/bin
if command -q mise
    mise activate fish | source
end
if test (uname) = Darwin
    fish_add_path /Library/TeX/texbin
    fish_add_path /Applications/Ghostty.app/Contents/MacOS
end
alias emacs='emacs-pgtk --init-directory ~/.config/emacs'
alias doom='~/.config/emacs/bin/doom'
