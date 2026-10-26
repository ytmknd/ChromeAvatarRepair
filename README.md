# ChromeAvatarRepair

A small Windows utility that fixes Google Chrome profile avatars that are missing, wrong, or stuck on an outdated image.

It resets the avatar-related settings of a selected Chrome profile, removes the cached profile pictures so Chrome downloads them again, and backs up everything it touches first.

## Features

- Lists all Chrome profiles found on the machine and lets you pick one
- Waits for you to close Chrome. **It never kills Chrome automatically**
- Backs up `Preferences` and `Local State` (plus any cache it removes) before changing anything
- Resets avatar settings in `Preferences` and `Local State`
- Removes the cached `Google Profile Picture.png` and `Accounts\Avatar Images`
- Writes a `RepairLog.txt` into the backup folder
- Relaunches Chrome with the repaired profile

## Requirements

- Windows 10 / 11
- Windows PowerShell 5.1 (included with Windows)
- Google Chrome

## Usage

1. Download `ChromeAvatarRepair.bat` and `ChromeAvatarRepair.ps1` and put them in the **same folder**.
2. Double-click `ChromeAvatarRepair.bat`.
3. Enter the number of the profile you want to repair and confirm.
4. Close all Chrome windows when prompted, then press ENTER.
5. The script creates a backup, repairs the profile, and starts Chrome again.

The `.bat` file simply runs the `.ps1` script with `-ExecutionPolicy Bypass` for that one session; it does not change your system execution policy.

## What it changes

**`Preferences`** (selected profile)

| Key | New value |
| --- | --- |
| `profile.avatar_index` | `-1` |
| `profile.using_default_avatar` | `true` |
| `profile.using_gaia_avatar` | `false` |
| `account_info[].last_downloaded_image_url_with_size` | `""` (for the matching account) |

**`Local State`** (`profile.info_cache.<profile>`)

| Key | New value |
| --- | --- |
| `avatar_icon` | `chrome://theme/IDR_PROFILE_AVATAR_26` |
| `is_using_default_avatar` | `true` |
| `use_gaia_picture` | `false` |
| `gaia_picture_file_name` | `""` |
| `last_downloaded_gaia_picture_url_with_size` | `""` |

**Deleted cache** (inside the profile folder)

- `Google Profile Picture.png`
- `Accounts\Avatar Images`

After relaunch, Chrome re-downloads the Google account picture for a signed-in profile.

## Backups

Backups are stored in Chrome's user data folder:

```
%LOCALAPPDATA%\Google\Chrome\User Data\AvatarRepairBackup_<profile>_<yyyyMMdd_HHmmss>\
```

Each backup contains `Preferences`, `Local State`, the removed cache files, and `RepairLog.txt`. To undo a repair, close Chrome and copy the backed-up files back to their original locations.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Completed successfully |
| `1` | An error occurred |
| `2` | Cancelled by the user |

## Disclaimer

This tool edits Chrome's internal configuration files, whose format may change between Chrome versions. A backup is always created first, but use it at your own risk.

## License

[MIT](LICENSE)
