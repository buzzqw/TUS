#!/bin/sh

javac Latex2MarkDown.java ; java Latex2MarkDown OBSSv2.tex OBSSv2.md

javac Latex2MarkDown.java ; java Latex2MarkDown OBSSv2-eng.tex OBSSv2-eng.md


sed -i 's/\\cline{[^}]*}//g' OBSSv2.md
sed -i '/Old Bell School System/c**Old Bell School System - OBSS - Fantasy Adventure Game**' OBSSv2.md
sed -i 's/D | D/D\&D/g' OBSSv2.md
sed -i 's/(pag\. )//g' OBSSv2.md
sed -i 's/\\cmidrule(lr)//g' OBSSv2.md
sed -i 's/%box narratore//g' OBSSv2.md
sed -i "s/'\\*\\*/' \\*\\*/g" OBSSv2.md
sed -i 's/\\hskip 0\.5cm//g' OBSSv2.md
sed -i '/| \*\*CM\*\* | \*\*PM\*\* | \*\*CM\*\* | \*\*PM\*\* | \*\*CM\*\* | \*\*PM\*\* |/a|---|---|---|---|---|---|' OBSSv2.md
sed -i 's/\\textbf//g' OBSSv2.md
sed -i '/| \*\*d\\%\*\* | \*\*Meteo\*\* | \*\*Clima Freddo\*\* | \*\*Clima Temperato {\*\*\*} | \*\*Deserto\*\* |/a|---|---|---|---|---|' OBSSv2.md
sed -i 's/| \*\*Minatore\*\* | \*\*Materiale da Scavare (1 minuto)\*\* |  | |/| **Minatore** | **Materiale da Scavare (1 minuto)** |  |/' OBSSv2.md
sed -i '/| Livello PG | Minima | Pericolosa | Mortale |/a|---|---|---|---|' OBSSv2.md
sed -i 's/{1\\textwidth}{mlllmc}//g' OBSSv2.md
sed -i '/{1\\textwidth}{$/,/^[[:space:]]*>{}p[[:space:]]*$/d' OBSSv2.md
sed -i '/| \*\*Tipo di movimento\*\* | \*\*Movimento\*\* |  | |/{N;s/| \*\*Tipo di movimento\*\* | \*\*Movimento\*\* |  | |\n| --- | --- | --- |/| **Tipo di movimento** | **Movimento** |  | |\n| --- | --- | --- |---|/;}' OBSSv2.md
sed -i '/| \*\*Zampe Creatura\*\* | \*\*CdC\*\* |/a|---|---|' OBSSv2.md
sed -i '/| \*\*Livello\*\* | \*\*PX\*\* | \*\*Livello\*\* | \*\*PX\*\* |/a|---|---|---|---|' OBSSv2.md
sed -i '/{@{}ll@ % @{} removes extra padding/d' OBSSv2.md
sed -i '/| \*\*Livello\*\* | \*\*Ricchezza (mo)\*\* | \*\*Livello\*\* | \*\*Ricchezza (mo)\*\* |/a|---|---|---|---|' OBSSv2.md
sed -i '/^{.*textwidth.*>/d' OBSSv2.md
sed -i '/| \*\*Tesori da tana o nascondigli di creature\*\* |  |  |  |  |  |  | |/{N;s/| --- | --- | --- | --- | --- | --- | --- |/| --- | --- | --- | --- | --- | --- | --- |---|/;}' OBSSv2.md
sed -i '/| \*\*Tesori Individuali, piccole tane, zaini e borse\*\* |  |  |  |  |  |  | |/{N;s/| --- | --- | --- | --- | --- | --- | --- |/| --- | --- | --- | --- | --- | --- | --- |---|/;}' OBSSv2.md
sed -i '/| \*\*Val\. tirato\*\* | \*\*Caratt\.\*\* | \*\*Val\. tirato\*\* | \*\*Caratt\.\*\* |/a|---|---|---|---|' OBSSv2.md
sed -i '/^[[:space:]]*>{}p$/,/^[[:space:]]*>{}p$/{/^[[:space:]]*>{}p$/d;/^[[:space:]]*>{\raggedright}X$/d;}' OBSSv2.md
sed -i 's/| \*\*4d6\*\* | \*\*Gemme\*\* | \*\*4d6\*\* | \*\*Gemme\*\* |\n| 4 | Quarzo | 16 | Topazio |/| \*\*4d6\*\* | \*\*Gemme\*\* | \*\*4d6\*\* | \*\*Gemme\*\* |\n|---|---|---|---|\n| 4 | Quarzo | 16 | Topazio |/' OBSSv2.md
sed -i '/| \*\*4d6\*\* | \*\*Bonus magico\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Capacità Speciale Armature\/Scudi Tipo 1\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Amuleti, Collane e Gioielli Tipo 1\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Amuleti, Collane e Gioielli Tipo 2\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Cinture, Elmi, Stivali e Guanti\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Bacchetta\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*3d6\*\* | \*\*Bastone\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Verga\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Pozione Tipo 1\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Pozione Tipo 2\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Pozione Tipo 3\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Anelli Tipo 1\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Anelli Tipo 2\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Cappelli, Mantelli, Occhiali, Tuniche\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*3d6\*\* | \*\*Rarità Pergamena\*\* | \*\*Pagine della Pergamena\*\* |/a\|---|---|---|' OBSSv2.md
sed -i '/| \*\*3d6\*\* | \*\*Livello Incantesimo\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*3d6\*\* | \*\*Manuali\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*3d6\*\* | \*\*Tomi\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Oggetti magici vari 1\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Oggetti magici vari 2\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Oggetti magici vari 3\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Oggetti magici vari 4\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Oggetto Magico\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*d100\*\* | \*\*Contiene\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| d\\% | Nemico prescelto |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Talento\*\* | \*\*1d100\*\* | \*\*Talento\*\* |/a\|---|---|---|---|' OBSSv2.md
sed -i '/| \*\*d10\*\* | \*\*Tipo di Danno\*\* | \*\*Gemma\*\* |/a\|---|---|---|' OBSSv2.md
sed -i '/| \*\*d100\*\* | \*\*Contenuti\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*Distanza dall'\''origine\*\* | \*\*Danno\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*d100\*\* | \*\*Effetto\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*3d6\*\* | \*\*Effetto\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*3d6\*\* | \*\*Sfera di\.\.\.\*\* | \*\*Incantesimo\*\* |/a\|---|---|---|' OBSSv2.md
sed -i '/| \*\*Faccia\*\* | \*\*Costo\*\* | \*\*Effetto\*\* |/a\|---|---|---|' OBSSv2.md
sed -i '/| 3d6 | Golem | Tempo | Costo |/a\|---|---|---|---|' OBSSv2.md
sed -i '/| \*\*\\%\*\* | \*\*Maledizione\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*\\%\*\* | \*\*Situazione\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*\\%\*\* | \*\*Inconveniente\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*GS\*\* | \*\*PX\*\* | \*\*GS\*\* | \*\*PX\*\* | \*\*GS\*\* | \*\*PX\*\* |/a\|---|---|---|---|---|---|' OBSSv2.md
sed -i '/| \\# | 1d8 | 1d8 | 1d8 |/a\|---|---|---|---|' OBSSv2.md
sed -i '/| \*\*d10\*\* | \*\*Comportamento\*\* |/a\|---|---|' OBSSv2.md
sed -i '/\\setlength\\itemsep{0em}/d' OBSSv2.md
sed -i '/\\makebox\[2\.5cm\]\[l\]/d' OBSSv2.md
sed -i '/| \*\*1d100\*\* | \*\*Capacità Speciale Armature\/Scudi Tipo 2\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*4d6\*\* | \*\*Gemme\*\* | \*\*4d6\*\* | \*\*Gemme\*\* |/a\|---|---|---|---|' OBSSv2.md
sed -i '/| --- | --- | --- | --- |/{n;/^[[:space:]]*$/d;}' OBSSv2.md
sed -i '/\\cline/,+1d' OBSSv2.md
sed -i 's/| 1 | Per 1 giorno non sei più in grado di canalizzare energie magiche\. Non puoi lanciare incantesimi se non facendo un successo magico critico nella Prova di Magia |/|3d6|Effetto|\n|---|---|\n| 1 | Per 1 giorno non sei più in grado di canalizzare energie magiche. Non puoi lanciare incantesimi se non facendo un successo magico critico nella Prova di Magia |/' OBSSv2.md
sed -i 's/### Cappelli, Mantelli, Occhiali, Tuniche\\hypertarget{Occhiali}{Occhiali}\\hypertarget{Cappelli}{Cappelli}/### Cappelli, Mantelli, Occhiali, Tuniche/' OBSSv2.md
sed -i 's/\\hypertarget{oggettimaledettiid}{\*\*identificati\*\*}/\*\*identificati\*\*/' OBSSv2.md
sed -i 's/\\hypertarget{visionecrepuscolare}{visione crepuscolare}/visione crepuscolare/' OBSSv2.md
sed -i '/{0\.50\\textwidth}/d' OBSSv2.md
sed -i '/{lp{0\.055\\textwidth}p{0\.06\\textwidth}p{0\.07\\textwidth/d' OBSSv2.md
sed -i '/\\begin{adjustbox}{max width=0\.5\\textwidth}/d' OBSSv2.md
sed -i '/| {>{\raggedright}p{0\.15\\textwidth}|>{\raggedright}p{0\.1\\textwidth}>{\raggedright}p{0\.15\\textwidth}|>{\raggedright}p{0\.1\\textwidth |/d' OBSSv2.md
sed -i '/| \*\*Costo\*\* | \*\*Oggetto\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| \*\*\\#\*\* | \*\*Effetto\*\* |/a\|---|---|' OBSSv2.md
sed -i '/| Ambiente:/,/| Organizzazione:/{s/| \(.*\) |/\1/g; /| --- |/d; /^---$/d;} ; /^Ambiente:/a\\' OBSSv2.md
sed -i 's/ \\emph / /g' OBSSv2.md
sed -i '/\*\*Categoria Tesoro\*\*:/{N;s/\(\*\*Categoria Tesoro\*\*:.*\)\n\(\*\*Descrizione\*\*\)/\1\n\n\2/;}' OBSSv2.md
sed -i 's/\\resizebox{0\.5\\linewidth+1\.8cm{!}{//g' OBSSv2.md
sed -i '/\\end{enumerate}/d' OBSSv2.md
sed -i '/\\begin{enumerate}\[leftmargin=\*\]/d' OBSSv2.md
sed -i 's/\\emph, altre entità/esseri, altre entità/g' OBSSv2.md
sed -i 's/aspettative di questi \\emph/aspettative di questi esseri/g' OBSSv2.md


sed -i 's/\\cline{[^}]*}//g' OBSSv2-eng.md
sed -i '/Old Bell School System/c**Old Bell School System - OBSS - Fantasy Adventure Game**' OBSSv2-eng.md
sed -i 's/D | D/D\&D/g' OBSSv2-eng.md
sed -i 's/(pag\. )//g' OBSSv2-eng.md
sed -i 's/\\cmidrule(lr)//g' OBSSv2-eng.md
sed -i 's/%box narratore//g' OBSSv2-eng.md
sed -i "s/'\\*\\*/' \\*\\*/g" OBSSv2-eng.md
sed -i 's/\\hskip 0\.5cm//g' OBSSv2-eng.md
sed -i '/| \*\*CM\*\* | \*\*PM\*\* | \*\*CM\*\* | \*\*PM\*\* | \*\*CM\*\* | \*\*PM\*\* |/a|---|---|---|---|---|---|' OBSSv2-eng.md
sed -i 's/\\textbf//g' OBSSv2-eng.md
sed -i 's/{Profession\*\*}/Profession\*\*/g' OBSSv2-eng.md
sed -i 's/{\\textwidth}{@{}X@{}X@{}X@{}X@{}X@//g' OBSSv2-eng.md
sed -i '/| \*\*d\\%\*\* | \*\*Weather\*\* | \*\*Cold Climate\*\* | \*\*Temperate Climate {\*\*\*} | \*\*Desert\*\* |/a|---|---|---|---|---|' OBSSv2-eng.md
sed -i 's/| \*\*Miner\*\* | \*\*Material to Dig (1 minute)\*\* |  | |/| **Miner** | **Material to Dig (1 minute)** |  |/' OBSSv2-eng.md
sed -i '/| Character Level | Minimal | Dangerous | Deadly |/a|---|---|---|---|' OBSSv2-eng.md
sed -i '/{1\\textwidth}{$/,/^[[:space:]]*>{}p[[:space:]]*$/d' OBSSv2-eng.md
sed -i '/^[[:space:]]*>{}p$/d; /^[[:space:]]*>{\raggedright}X$/d' OBSSv2-eng.md
sed -i '/| \*\*Movement type\*\* | \*\*Movement\*\* |  | |/{N;s/| --- | --- | --- |/| --- | --- | --- |---|/;}' OBSSv2-eng.md
sed -i '/| \*\*Creature Legs\*\* | \*\*CdC\*\* |/a|---|---|' OBSSv2-eng.md
sed -i '/| \*\*Level\*\* | \*\*XP\*\* | \*\*Level\*\* | \*\*XP\*\* |/a|---|---|---|---|' OBSSv2-eng.md
sed -i '/{@{}ll@ % @{} removes extra padding/d' OBSSv2-eng.md
sed -i '/| \*\*Level\*\* | \*\*Wealth (gp)\*\* | \*\*Level\*\* | \*\*Wealth (gp)\*\* |/c| Level | Wealth (gp) | Level | Wealth (gp) |\n|---|---|---|---|' OBSSv2-eng.md
sed -i '/^{.*textwidth.*>/d' OBSSv2-eng.md
sed -i '/| \*\*Treasures from lairs or hideouts of creatures\*\* |  |  |  |  |  |  | |/{N;s/| --- | --- | --- | --- | --- | --- | --- |/| --- | --- | --- | --- | --- | --- | --- |---|/;}' OBSSv2-eng.md
sed -i '/| \*\*Individual Treasures, small lairs, backpacks and bags\*\* |  |  |  |  |  |  | |/{N;s/| --- | --- | --- | --- | --- | --- | --- |/| --- | --- | --- | --- | --- | --- | --- |---|/;}' OBSSv2-eng.md
sed -i '/| \*\*Roll value\*\* | \*\*Ability\*\* | \*\*Roll value\*\* | \*\*Ability\*\* |/a|---|---|---|---|' OBSSv2-eng.md
sed -i '/^{1\\textwidth}{mlllmc}$/d' OBSSv2-eng.md
sed -i '/^[[:space:]]*>{\raggedright}X$/d' OBSSv2-eng.md
sed -i '/| \*\*4d6\*\* | \*\*Gems\*\* | \*\*4d6\*\* | \*\*Gems\*\* |/a\|---|---|---|---|' OBSSv2-eng.md
sed -i '/| \*\*4d6\*\* | \*\*Magic bonus\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Special Ability Armor\/Shields Type 1\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Amulets, Necklaces and Jewelry Type 1\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Amulets, Necklaces and Jewelry Type 2\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Belts, Helmets, Boots and Gloves\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Wand\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*3d6\*\* | \*\*Staff\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Rod\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Potion Type 1\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Potion Type 2\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Potion Type 3\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Rings Type 1\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Rings Type 2\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Hats, Cloaks, Glasses, Robes\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/\\hypertarget{Glasses}{Glasses}\\hypertarget{Hats}{Hats}/d' OBSSv2-eng.md
sed -i '/| \*\*3d6\*\* | \*\*Scroll Rarity\*\* | \*\*Pages on Scroll\*\* |/a\|---|---|---|' OBSSv2-eng.md
sed -i '/| \*\*3d6\*\* | \*\*Spell Level\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*3d6\*\* | \*\*Manuals\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*3d6\*\* | \*\*Tomes\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Miscellaneous magic items 1\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Miscellaneous magic items 2\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Miscellaneous magic items 3\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Miscellaneous magic items 4\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Magic Item\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| d\\% | Chosen enemy |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Feat\*\* | \*\*1d100\*\* | \*\*Feat\*\* |/a\|---|---|---|---|' OBSSv2-eng.md
sed -i '/| \*\*d10\*\* | \*\*Damage Type\*\* | \*\*Gem\*\* |/a\|---|---|---|' OBSSv2-eng.md
sed -i '/| \*\*d100\*\* | \*\*Contents\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*Distance from origin\*\* | \*\*Damage\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*d100\*\* | \*\*Effect\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*3d6\*\* | \*\*Bead of\.\.\.\*\* | \*\*Spell\*\* |/a\|---|---|---|' OBSSv2-eng.md
sed -i '/| \*\*Face\*\* | \*\*Cost\*\* | \*\*Effect\*\* |/a\|---|---|---|' OBSSv2-eng.md
sed -i '/| 3d6 | Golem | Time | Cost |/a\|---|---|---|---|' OBSSv2-eng.md
sed -i '/| \*\*\\%\*\* | \*\*Curse\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*\\%\*\* | \*\*Situation\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*\\%\*\* | \*\*Drawback\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*CR\*\* | \*\*XP\*\* | \*\*CR\*\* | \*\*XP\*\* | \*\*CR\*\* | \*\*XP\*\* |/a\|---|---|---|---|---|---|' OBSSv2-eng.md
sed -i '/| \*\*d10\*\* | \*\*Behavior\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*3d6\*\* | \*\*Effect\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \\# | 1d8 | 1d8 | 1d8 |/a\|---|---|---|---|' OBSSv2-eng.md
sed -i '/\\makebox\[2\.5cm\]\[l\]/d' OBSSv2-eng.md
sed -i '/\\setlength\\itemsep{0em}/d' OBSSv2-eng.md
sed -i '/\\end{adjustbox}/d' OBSSv2-eng.md
sed -i '/| {>{\raggedright}p{0\.15\\textwidth}|>{\raggedright}p{0\.1\\textwidth}>{\raggedright}p{0\.15\\textwidth}|>{\raggedright}p{0\.1\\textwidth |/d' OBSSv2-eng.md
sed -i '/| \*\*1d100\*\* | \*\*Special Ability Armor\/Shields Type 2\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*d100\*\* | \*\*Contains\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*MP\*\* | \*\*MP\*\* | \*\*MP\*\* | \*\*MP\*\* | \*\*MP\*\* | \*\*MP\*\* |/a\|---|---|---|---|---|---|' OBSSv2-eng.md
sed -i '/| --- | --- | --- | --- |/{n;/^[[:space:]]*$/d;}' OBSSv2-eng.md
sed -i '/\\cline/,+1d' OBSSv2-eng.md
sed -i 's/| 1 | For 1 day you are no longer able to channel magical energies\. You cannot cast spells unless making a magic critical success in the Magic Check |/|3d6|Effect|\n|---|---|\n| 1 | For 1 day you are no longer able to channel magical energies. You cannot cast spells unless making a magic critical success in the Magic Check |/' OBSSv2-eng.md
sed -i 's/\\hypertarget{curseditemsid}{\*\*identified\*\*}/\*\*identified\*\*/' OBSSv2-eng.md
sed -i 's/\\hypertarget{visionecrepuscolare}{twilight vision}/twilight vision/' OBSSv2-eng.md
sed -i 's/\\hypertarget{Hunter'\''s lens}{Hunter'\''s lens}/Hunter'\''s lens/' OBSSv2-eng.md
sed -i '/{0\.50\\textwidth}/d' OBSSv2-eng.md
sed -i '/{lp{0\.055\\textwidth}p{0\.06\\textwidth}p{0\.07\\textwidth/d' OBSSv2-eng.md
sed -i '/\\begin{adjustbox}{max width=0\.5\\textwidth}/d' OBSSv2-eng.md
sed -i '/| {>{\raggedright}p{0\.15\\textwidth}|>{\raggedright}p{0\.1\\textwidth}>{\raggedright}p{0\.15\\textwidth}|>{\raggedright}p{0\.1\\textwidth |/d' OBSSv2-eng.md
sed -i '/| Environment:/,/| Organization:/{s/| \(.*\) |/\1/g; /| --- |/d; /^---$/d;} ; /^Environment:/a\\' OBSSv2-eng.md
sed -i '/| \*\*\\#\*\* | \*\*Effect\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i '/| \*\*Cost\*\* | \*\*Item\*\* |/a\|---|---|' OBSSv2-eng.md
sed -i 's/\*\*\\emph\*\*//g' OBSSv2-eng.md
sed -i 's/ \\emph / /g' OBSSv2-eng.md
sed -i '/\*\*Treasure Category\*\*:/{N;s/\(\*\*Treasure Category\*\*:.*\)\n\(\*\*Description\*\*\)/\1\n\n\2/;}' OBSSv2-eng.md
sed -i 's/\\resizebox{0\.5\\linewidth+1\.4cm{!}{//g' OBSSv2-eng.md
sed -i '/\\end{enumerate}/d' OBSSv2-eng.md
sed -i '/\\begin{enumerate}\[leftmargin=\*\]/d' OBSSv2-eng.md


awk '/^---$/ {if (prev_line != "" && prev_line !~ /^[[:space:]]*$/) print ""; print $0; next} {print $0; prev_line = $0}' OBSSv2.md > obtemp.md && mv obtemp.md OBSSv2.md
awk '/^---$/ {if (prev_line != "" && prev_line !~ /^[[:space:]]*$/) print ""; print $0; next} {print $0; prev_line = $0}' OBSSv2-eng.md > obtemp.md && mv obtemp.md OBSSv2-eng.md
awk '/^$/{e++} !/^$/{e=0} e<=2' OBSSv2-eng.md > obtemp && mv obtemp OBSSv2-eng.md
awk '/^$/{e++} !/^$/{e=0} e<=2' OBSSv2.md > obtemp && mv obtemp OBSSv2.md
