#!/bin/sh

javac Latex2MarkDown.java ; java Latex2MarkDown OBSSv2.tex OBSSv2.md

javac Latex2MarkDown.java ; java Latex2MarkDown OBSSv2-eng.tex OBSSv2-eng.md


sed -i 's/\\cline{[^}]*}//g' OBSSv2.md
sed -i '/Old Bell School System/c\
**Old Bell School System - OBSS - Fantasy Adventure Game**' OBSSv2.md
sed -i 's/D | D/D\&D/g' OBSSv2.md
sed -i 's/(pag\. )//g' OBSSv2.md
sed -i 's/\\cmidrule(lr)//g' OBSSv2.md
sed -i 's/%box narratore//g' OBSSv2.md
sed -i "s/'\\*\\*/' \\*\\*/g" OBSSv2.md
sed -i 's/\\hskip 0\.5cm//g' OBSSv2.md
sed -i '/| \*\*CM\*\* | \*\*PM\*\* | \*\*CM\*\* | \*\*PM\*\* | \*\*CM\*\* | \*\*PM\*\* |/a\
|---|---|---|---|---|---|' OBSSv2.md
