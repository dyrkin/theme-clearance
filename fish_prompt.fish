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

function _git_branch_name
    echo (command git symbolic-ref HEAD ^/dev/null | sed -e 's|^refs/heads/||')
end

function _git_is_dirty
    echo (command git status -s --ignore-submodules=dirty ^/dev/null)
end

function _remote_hostname
    if test -n "$SSH_CONNECTION"
        echo "ssh "
    end
end

function __git_ahead_verbose -S -d 'Print a more verbose ahead/behind state for the current branch'
    set -l commits (command git rev-list --left-right '@{upstream}...HEAD' 2>/dev/null)
    or return

    set -l behind (count (for arg in $commits; echo $arg; end | command grep '^<'))
    set -l ahead (count (for arg in $commits; echo $arg; end | command grep -v '^<'))

    set -l ahead_msg (echo $red"$git_ahead_glyph$ahead")
    set -l behind_msg (echo $green"$git_behind_glyph$behind")

    switch "$ahead $behind"
        case '' # no upstream
        case '0 0' # equal to upstream
            return
        case '* 0' # ahead of upstream
            echo "[$ahead_msg$normal]"
        case '0 *' # behind upstream
            echo "[$behind_msg$normal]"
        case '*' # diverged from upstream
            echo "[$ahead_msg$behind_msg$normal]"
    end
end

function __git_untracked
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

function fish_prompt
    set -l last_status $status

    set -l cwd $blue(pwd | sed "s:^$HOME:~:")

    # Output the prompt, left to right

    # Add a newline before new prompts
    echo -e ''

    # Display [venvname] if in a virtualenv
    if set -q VIRTUAL_ENV
        echo -n -s (set_color -b cyan black) '[' (basename "$VIRTUAL_ENV") ']' $normal ' '
    end

    # Print pwd or full path
    echo -n -s $cwd $normal

    # Show git branch and status
    set -l staged (command git diff --cached --no-ext-diff --quiet --exit-code 2>/dev/null; or echo -n "$git_staged_glyph")
    set -l stashed (command git rev-parse --verify --quiet refs/stash >/dev/null; and echo -n "$git_stashed_glyph")
    set -l untracked (__git_untracked)
    set -l ahead (__git_ahead_verbose)
    set -l dirty (_git_is_dirty)

    #$staged $stashed $untracked

    set -l git_branch (_git_branch_name)

    if [ "$git_branch" ]
        if [ "$dirty" ]
            set git_info '(' $yellow $git_branch "±" $normal ')'
        else
            set git_info '(' $green $git_branch $normal ')'
        end
        echo -n -s ' · ' $git_info $normal "$ahead"

        set -l prompt_color $red
        if test $last_status = 0
            set prompt_color $normal
        end
    end

    # Terminate with a nice prompt char
    echo -e ''
    echo -e -n -s (_remote_hostname) $prompt_color '⟩ ' $normal
end
