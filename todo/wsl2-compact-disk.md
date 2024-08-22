# WSL2 Compact Disk

```powershell
#locate ext4.vhdx file with everything or windirstat. copy path
#open powershell
wsl --shutdown
diskpart
DISKPART> select vdisk file="<path to .vhdx>"
DISKPART> compact disk
```
