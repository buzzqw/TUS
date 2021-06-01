export NO_AT_BRIDGE=1

pandoc -s "/home/azanzani/TUS/DBS/DBS - Dungeon Bell System.tex" -o "/home/azanzani/TUS/DBS/DBS - Dungeon Bell System.docx"

git config --global credential.helper cache
git ls-files --others --exclude-from=.git/info/exclude
git add "/home/azanzani/TUS/"
git add "/home/azanzani/DBS/changelog.md"
git add "/home/azanzani/DBS/CODE_OF_CONDUCT.md"
git add "/home/azanzani/DBS/copertina.png"
git add "/home/azanzani/DBS/immagini/"
git add "/home/azanzani/DBS/DBS-abilita-arma-armature.tex"
git add "/home/azanzani/DBS/DBS - Dungeon Bell System.tex"
git add "/home/azanzani/DBS/DBS-magia-alternativa.tex"
git add "/home/azanzani/DBS/DBS-monstruos-chapter.tex"
git add "/home/azanzani/DBS/DBS-scheda.ods"
git add "/home/azanzani/DBS/DBS-scheda.pdf"
git add "/home/azanzani/DBS/diario.md"
git add "/home/azanzani/DBS/LICENSE.md"
git add "/home/azanzani/TUS/README.md"
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


rclone copy "/home/azanzani/TUS/DBS/DBS-abilita-arma-armature.tex" mega:
rclone copy "/home/azanzani/TUS/DBS/DBS - Dungeon Bell System.tex" mega:
rclone copy "/home/azanzani/TUS/DBS/DBS-magia-alternativa.tex" mega:
rclone copy "/home/azanzani/TUS/DBS/DBS-monstruos-chapter.tex" mega:
rclone copy "/home/azanzani/TUS/DBS/DBS-scheda.ods" mega:
rclone copy "/home/azanzani/TUS/DBS/DBS - Dungeon Bell System.pdf" mega:

rclone dedupe mega:

#git push origin master

#! [remote rejected] master -> master (shallow update not allowed)
# git fetch --unshallow https://azanzani%40gmail.com:Musetto37913791@github.com/buzzqw/TUS.git
