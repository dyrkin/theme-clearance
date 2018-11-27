# name: clearance
# ---------------
# Based on idan. Display the following bits on the left:
# - Virtualenv name (if applicable, see https://github.com/adambrenecki/virtualfish)
# - Current directory name
# - Git branch and dirty state (if inside a git repo)

  set -x git_ahead_glyph      \u2191 # '↑'
  set -x git_behind_glyph     \u2193 # '↓'

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

    switch "$ahead $behind"
        case '' # no upstream
        case '0 0' # equal to upstream
            return
        case '* 0' # ahead of upstream
            echo "$git_ahead_glyph$ahead"
        case '0 *' # behind upstream
            echo "$git_behind_glyph$behind"
        case '*' # diverged from upstream
            echo "$git_ahead_glyph$ahead$git_behind_glyph$behind"
    end
end

function fish_prompt
    set -l last_status $status

    set -l cyan (set_color cyan)
    set -l yellow (set_color yellow)
    set -l red (set_color red)
    set -l blue (set_color blue)
    set -l green (set_color green)
    set -l normal (set_color normal)

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
    if [ (_git_branch_name) ]
        set -l git_branch (_git_branch_name)

        if [ (_git_is_dirty) ]
            set git_info '(' $yellow $git_branch "±" $normal ')'
        else
            set git_info '(' $green $git_branch $normal ')'
        end
        echo -n -s ' · ' $git_info $normal (__git_ahead_verbose)
    end

    set -l prompt_color $red
    if test $last_status = 0
        set prompt_color $normal
    end

    # Terminate with a nice prompt char
    echo -e ''
    echo -e -n -s (_remote_hostname) $prompt_color '⟩ ' $normal
end
