#!/bin/sh

cd $HOME"/TUS/"

rclone -v sync "The Untitled Bell System.tex" drive:TUS	#carica nella cartella TUS
rclone -v sync "The Untitled Bell System.pdf" drive:TUS/materiale  #carica nella cartella TUS/materiale
rclone -v sync "TUS-schedav6.pdf" drive:TUS/materiale  #carica nella cartella TUS/materiale
rclone -v sync "TUS-schedav6.ods" drive:TUS  #carica nella cartella TUS
rclone -v sync "simboli-dei-antichi1.pdf" drive:TUS
rclone -v sync "simboli-dei-antichi2.pdf" drive:TUS
rclone -v sync "DBS-monstruos-chapter.tex" drive:TUS
rclone -v sync "esempi-magie.tex" drive:TUS
rclone -v sync "LICENSE.pdf" drive:TUS
rclone -v sync "LICENSE.pdf" drive:TUS/DBS
rclone -v sync "DBS - Dungeon Bell System.tex" drive:TUS/DBS
rclone -v sync "DBS - Dungeon Bell System.pdf" drive:TUS/DBS
rclone -v sync "DBS-magia-alternativa.tex" drive:TUS/DBS
rclone -v sync "DBS-schedav6.ods" drive:TUS/DBS
rclone -v sync "DBS-schedav6.pdf" drive:TUS/DBS
rclone -v sync "DBS-schedav7.ods" drive:TUS/DBS
rclone -v sync "DBS-schedav7.pdf" drive:TUS/DBS
rclone -v sync "DBS-abilita-arma-armature.tex" drive:TUS/DBS
rclone -v sync "DBS-monstruos-chapter.tex" drive:TUS/DBS

#pandoc "The Untitled Bell System.tex" -o "The Untitled Bell System.docx"
#"/home/azanzani/Dropbox/Ad&ZZ/Pazfinder/gdrive-linux-x64-patch2" import -p 1ECqikLlKV2v1iRlRsIi3VRf9SYmnU_95 "The Untitled Bell System.docx"

#old folder 1TTlbpw9EsLOanl554QEquQe7L06zubOM
#tus folder 1oIr5NoI6U-Fqg_ksgfQfft8tFfcwKjXo
#materiele folder 1ZCwnkMcIZX6MTkN8qn6XKzBAuhQLylDp
#dbs 1N-m2GEgjPlFoqRhg9rNfnupTj-_TFzJa