nvALL automatically saves a version of your note every time you edit it.

How It Works
  - Each save creates a timestamped snapshot in a .versions folder alongside your notes
  - Versions older than 5 days are automatically cleaned up
  - You can configure the maximum number of versions per note in Preferences (default: 50)

Reverting to a Previous Version
  - Right-click any note in the list
  - The context menu shows "Revert to Version" with the 10 most recent versions
  - Older versions are grouped by date in submenus
  - Selecting a version replaces the current content (a backup of the current version is saved first)

Safety
  - nvALL never overwrites a non-empty note with empty content
  - Before reverting, the current content is saved as a version, so you can always undo a revert
  - Version files are plain text, stored in: [notes folder]/.versions/[note name]/

Deleting Notes
  - Right-click a note and select "Delete Note"
  - This removes the file from disk permanently
