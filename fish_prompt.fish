# name: clearance
# ---------------
# Based on idan. Display the following bits on the left:
# - Virtualenv name (if applicable, see https://github.com/adambrenecki/virtualfish)
# - Current directory name
# - Git branch and dirty state (if inside a git repo)

#glyphs
set -x git_ahead_glyph \u2191 # '↑'
set -x git_behind_glyph \u2193 # '↓'
set -x git_staged_glyph '~'
set -x git_stashed_glyph '$'
set -x git_untracked_glyph '…'

#colors
set -x cyan (set_color cyan)
set -x yellow (set_color yellow)
set -x red (set_color red)
set -x blue (set_color blue)
set -x green (set_color green)
set -x normal (set_color normal)

function ssh::label
    if test -n "$SSH_CONNECTION"
        echo "ssh "
    end
end

function git::branch_name
    echo (command git symbolic-ref HEAD ^/dev/null | sed -e 's|^refs/heads/||')
end

function git::is_dirty
    echo (command git status -s --ignore-submodules=dirty ^/dev/null)
end

function git::ahead -S -d 'Print a more verbose ahead/behind state for the current branch'
    set -l commits (command git rev-list --left-right '@{upstream}...HEAD' 2>/dev/null)
    or return

    set -l ahead (count (for arg in $commits; echo $arg; end | command grep -v '^<'))

    set -l ahead_msg (echo $red"$git_ahead_glyph$ahead")

    switch "$ahead"
        case '' # no upstream
        case '0' # equal to upstream
            return
        case '*' # ahead of upstream
            echo "[$ahead_msg$normal]"
    end
end

function git::behind -S -d 'Print a more verbose ahead/behind state for the current branch'
    set -l commits (command git rev-list --left-right '@{upstream}...HEAD' 2>/dev/null)
    or return

    set -l behind (count (for arg in $commits; echo $arg; end | command grep '^<'))

    set -l behind_msg (echo $green"$git_behind_glyph$behind")

    switch "$behind"
        case '' # no upstream
        case '0' # equal to upstream
            return
        case '*' # behind upstream
            echo "[$behind_msg$normal]"
    end
end

function git::untracked
    set -l show_untracked (command git config --bool bash.showUntrackedFiles 2>/dev/null)
    if [ "$show_untracked" != 'false' ]
        set -l new (command git ls-files --other --exclude-standard --directory --no-empty-directory 2>/dev/null)
        if [ "$new" ]
            echo "$git_untracked_glyph"
        else
            return
        end
    end
end

function git::staged
    echo -n (command git diff --cached --no-ext-diff --quiet --exit-code 2>/dev/null; or echo -n "$git_staged_glyph")
end

function git::stashed
    echo -n (command git rev-parse --verify --quiet refs/stash >/dev/null; and echo -n "$git_stashed_glyph")
end

function git::git
    set -l staged (git::staged)
    set -l stashed (git::stashed)
    set -l untracked (git::untracked)
    set -l ahead (git::ahead)
    set -l behind (git::behind)


    if [ "$staged" ]
        set ret_val "$ret_val$staged|"
    end

    if [ "$stashed" ]
        set ret_val "$ret_val$stashed|"
    end

    if [ "$untracked" ]
        set ret_val "$ret_val$untracked|"
    end

    if [ "$ahead" ]
        set ret_val "$ret_val$ahead|"
    end

    if [ "$behind" ]
        set ret_val "$ret_val$ahead|"
    end

    set ret_val (string trim -r -c "|" "$ret_val")

    if [ "$ret_val" ]
        echo "[$ret_val]"
    else
        return
    end
end

function fish_prompt
    set -l last_status $status

    set -l cwd $blue(pwd | sed "s:^$HOME:~:")

    # Add a newline before new prompts
    echo -e ''

    # Display [venvname] if in a virtualenv
    if set -q VIRTUAL_ENV
        echo -n -s (set_color -b cyan black) '[' (basename "$VIRTUAL_ENV") ']' $normal ' '
    end

    # Print pwd or full path
    echo -n -s $cwd $normal

    # Show git branch and status
    set -l git_branch (git::branch_name)

    if [ "$git_branch" ]
        set -l is_dirty (git::is_dirty)

        if [ "$is_dirty" ]
            set git_info '(' $yellow $git_branch $normal ')'
        else
            set git_info '(' $green $git_branch $normal ')'
        end
        echo -n -s ' · ' $git_info $normal

        set -l prompt_color $red
        if test $last_status = 0
            set prompt_color $normal
        end
    end

    set -l ssh_label (ssh::label)

    # Terminate with a nice prompt char
    echo -e ''
    echo -e -n -s $normal $ssh_label $prompt_color '⟩ ' $normal
end

function fish_right_prompt
    echo (git::git)
end
