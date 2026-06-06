# cide / cmux-workspace-dbt — task runner.  `just` or `just --list` shows recipes.
# Opened in the task-runner pane of the cide IDE layout.

# list available recipes (default)
default:
    @just --list

# resolved profile / config axes / state / tools
doctor:
    cwd doctor

# capture a versioned cmux fidelity snapshot (static CLI surface)
fidelity:
    ./fidelity/cmux-snapshot.sh

# run git hooks locally (lefthook)
hooks:
    lefthook run pre-commit
