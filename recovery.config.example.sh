# Source this file before running restore_analysis_state.py.
# REKORDBOX_DB_KEY is required. Supply it privately through the environment.
# Never commit the database key.
# export REKORDBOX_DB_KEY=...
# Defaults below can be overridden with WSL paths to your Windows directories.
export REKORDBOX_ROOT="$HOME/AppData/Roaming/Pioneer/rekordbox"
export REKORDBOX_RECOVERY="$HOME/rekordbox-recovery"
export REKORDBOX_POWERSHELL="powershell.exe"
# After reviewing a dry run, set its verified_candidates count before --apply.
# export REKORDBOX_EXPECTED_CANDIDATES=...
