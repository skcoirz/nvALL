nvALL stores your notes as plain files in a folder you choose.

Supported File Formats
  - Markdown (.md) — default for new notes
  - Plain Text (.txt)
  - Rich Text (.rtf) — read-only, content is extracted as plain text

Changing the Storage Folder
  - Open Preferences with Cmd+,
  - Click "Choose..." to select a folder
  - You can point nvALL at an existing folder of notes (e.g., from nvALT or any other app)
  - Changes take effect after restarting the app

Changing the Default File Format
  - In Preferences, choose between Markdown (.md) and Plain Text (.txt)
  - This only affects new notes — existing notes keep their original format

Version History Settings
  - "Max versions per note" controls how many snapshots are kept (default: 50)
  - Versions older than 5 days are automatically removed

Where Are Things Stored?
  - Notes: the folder you choose (default: ~/.nvALL/)
  - Version history: [notes folder]/.versions/
  - Preferences: macOS UserDefaults (automatic)
  - Cursor positions: remembered per note across sessions
