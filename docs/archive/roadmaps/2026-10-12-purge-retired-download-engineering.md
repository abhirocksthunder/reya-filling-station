# Published purge and retired-download engineering

Published signed stable Patch 3 for base v1.0.33+34 and website revision 20261012171506-81291e1b070e297f. Removed six retired public APK files; older version links redirect to the current APK and retired release entries are hidden. Purge stores local handover tombstones, uses server-only deletion reads and shows incomplete cloud deletion in red. 126 Flutter tests including stale-cache resurrection regression and 22 release checks passed; published revision/code/current APK hashes and older-link redirects verified. Firebase HTTP 429 Quota exceeded blocked deletion of 17 older cloud release records; four cloud handovers remain until the owner retries purge successfully. Physical-device testing skipped under standing owner authorization. No live financial records were deleted by maintenance.

Cloud cleanup remains pending in the canonical roadmap.
