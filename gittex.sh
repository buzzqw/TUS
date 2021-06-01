export NO_AT_BRIDGE=1

pandoc -s "/home/azanzani/TUS/DBS - Dungeon Bell System.tex" -o "DBS - Dungeon Bell System.docx"
zip -1 "/home/azanzani/TUS/TUS-git.zip" "/home/azanzani/TUS/screen.odt" "/home/azanzani/TUS/bell-lulu6.png" "/home/azanzani/TUS/copertina.png" "/home/azanzani/TUS/esempi-magie.tex" "/home/azanzani/TUS/gittex.sh" "/home/azanzani/TUS/magia-alternativa.tex" "/home/azanzani/TUS/DBS-monstruos-chapter.tex" "/home/azanzani/TUS/README.md" "/home/azanzani/TUS/The Untitled Bell System.pdf" "/home/azanzani/TUS/The Untitled Bell System.tex" "/home/azanzani/TUS/TUS-schedav6.ods" "/home/azanzani/TUS/TUS-schedav6.pdf" "/home/azanzani/TUS/DBS - Dungeon Bell System.tex" "/home/azanzani/TUS/DBS-magia-alternativa.tex" "/home/azanzani/TUS/DBS-abilita-arma-armature.tex" "/home/azanzani/TUS/DBS-scheda.ods" "/home/azanzani/TUS/DBS - Dungeon Bell System.pdf" "/home/azanzani/TUS/DBS-scheda.pdf" "/home/azanzani/TUS/theoldmagic.tex" "/home/azanzani/TUS/theoldmagic.pdf"
rsync -a "screen.odt" "TUS-git.zip" "/home/azanzani/TUS/bell-lulu6.png" "DBS-abilita-arma-armature.tex" "DBS-scheda.ods" "DBS-scheda.pdf" "DBS - Dungeon Bell System.tex" "DBS-magia-alternativa.tex" "The Untitled Bell System.tex" "The Untitled Bell System.pdf" "copertina.png" "The Untitled Bell System.docx" "TUS-schedav6.ods" "TUS-schedav6.pdf" "DBS-monstruos-chapter.tex" "magia-alternativa.tex" "/home/azanzani/TUS/esempi-magie.tex" "/home/azanzani/TUS/DBS-abilita-arma-armature.tex" "/home/azanzani/TUS/gittex.sh" "DBS - Dungeon Bell System.pdf" "theoldmagic.tex" "theoldmagic.pdf" $HOME"/Dropbox/Ad&ZZ/Pazfinder/"

rsync -a $HOME"/Dropbox/Federica/Le avventure di una mezza Pixie.odt" /home/azanzani/TUS/
rsync -a $HOME"/Dropbox/Federica/Nuove avventure di una fatina.odt" /home/azanzani/TUS/


git config --global credential.helper cache
git add "/home/azanzani/TUS/"
git add "/home/azanzani/DBS/"
git add "/home/azanzani/altro/"
#git add "/home/azanzani/TUS/immagini/*"
#git add "DBS-schedav6.ods"
#git add "DBS-schedav6.pdf"
#git add "diario.md"
#git add "Le avventure di una mezza Pixie.odt"
#git add "Nuove avventure di una fatina.odt"
#git add "screen.odt"
#git add "TUS-Scheda-1.png"
#git add "TUS-Scheda-2.png"

commento=$(zenity --width=300 --entry --title="Inserisci commento al commit")
git commit -am "$commento"
#git push https://azanzani%40gmail.com:Musetto37913791@github.com/buzzqw/TUS.git
git push https://buzzqw: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@github.com/buzzqw/TUS.git
#git push https://github-ci-token:ad61b7957469255fde008a4f1c59fff6e868e131@github.com/buzzqw/TUS.git


rclone copy "DBS/DBS-abilita-arma-armature.tex" mega:
rclone copy "DBS/DBS - Dungeon Bell System.tex" mega:
rclone copy "DBS/DBS-magia-alternativa.tex" mega:
rclone copy "DBS/DBS-monstruos-chapter.tex" mega:
rclone copy "DBS/DBS-scheda.ods" mega:
rclone copy "DBS/DBS - Dungeon Bell System.pdf" mega:

rclone dedupe mega:

#git push origin master

#! [remote rejected] master -> master (shallow update not allowed)
# git fetch --unshallow https://azanzani%40gmail.com:Musetto37913791@github.com/buzzqw/TUS.git
