### BACKUP's

Modo de uso

```
lucho@cloud:~/hardware$ ./backup.sh <type> (full|diff|inc) path-absolute
```

### Ejemplo

```
lucho@cloud:~/hardware$ ./backups.sh full /home/lucho/hardware/dev
```

Carpeta a respaldar

```
dev
├── A
│   └── A
├── B
│   └── B
└── C
    └── C
```

Archivos del script

```
backups
├── history
│   └── dev.snap
└── log
    ├── backup.log
    └── old
        └── backup_29nov21.log
```

TAR's con las copias

```
s3/
└── full_dev_29nov21.tar.gz
```