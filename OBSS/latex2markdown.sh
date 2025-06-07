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


awk '/^$/{e++} !/^$/{e=0} e<=2' OBSSv2-eng.md > obtemp && mv obtemp OBSSv2-eng.md
awk '/^$/{e++} !/^$/{e=0} e<=2' OBSSv2.md > obtemp && mv obtemp OBSSv2.md
