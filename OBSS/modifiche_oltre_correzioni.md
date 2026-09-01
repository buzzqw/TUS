# Interventi oltre le semplici correzioni di battitura

Documento di dettaglio per i 7 interventi su `OBSSv2.tex` che vanno oltre le correzioni di battitura/sintassi.
Per ogni punto: **PRIMA** (testo originale nel commit precedente) e **DOPO** (testo attuale nel file).

---

## 1. Sciame di Ratti — rimosso un blocco duplicato e corrotto

Nella voce `\mostro{Sciame di Ratti}` l'originale conteneva, dopo il blocco corretto, un secondo blocco identico per struttura ma corrotto da copia-incolla (tratto errato "Minuscolo insetto", valori incoerenti `Morsi +3` e `Colpisce 10 (4d4)`).

**PRIMA** (blocco completo della voce, dopo `Olfatto Affinato`):

```
\emph{\textbf{Sciame.}} Lo sciame può occupare lo spazio di un'altra creatura e viceversa, lo sciame può muoversi attraverso qualsiasi apertura grande abbastanza per un Minuscolo ratto. Lo sciame non può recuperare Punti Ferita né ottenere Punti Ferita temporanei.

\textbf{Azioni}

\emph{\textbf{Morsi.} Attacco con Arma da Mischia}: +4 a colpire, portata 0 m, un bersaglio nello spazio dello sciame.

\emph{Colpisce:} 7 (2d6) danni perforanti, o 3 (1d6) danni perforanti se lo sciame è ha metà o meno dei suoi Punti Ferita.

\emph{\textbf{Sciame.}} Lo sciame può occupare lo spazio di un'altra creatura e viceversa, lo sciame può muoversi attraverso qualsiasi apertura grande abbastanza per un Minuscolo insetto. Lo sciame non può recuperare Punti Ferita né ottenere Punti Ferita temporanei.

\textbf{Azioni}

\emph{\textbf{Morsi.} Attacco con Arma da Mischia}: +3 a colpire, portata 0 m, un bersaglio nello spazio dello sciame.

\emph{Colpisce:} 10 (4d4) danni perforanti, o 5 (2d4) danni perforanti se lo sciame è ha metà o meno dei suoi Punti Ferita.
```

**DOPO**:

```
\emph{\textbf{Sciame.}} Lo sciame può occupare lo spazio di un'altra creatura e viceversa, lo sciame può muoversi attraverso qualsiasi apertura grande abbastanza per un Minuscolo ratto. Lo sciame non può recuperare Punti Ferita né ottenere Punti Ferita temporanei.

\textbf{Azioni}

\emph{\textbf{Morsi.} Attacco con Arma da Mischia}: +4 a colpire, portata 0 m, un bersaglio nello spazio dello sciame.

\emph{Colpisce:} 7 (2d6) danni perforanti, o 3 (1d6) danni perforanti se lo sciame ha metà o meno dei suoi Punti Ferita.
```

Unica altra modifica: `sciame è ha metà` → `sciame ha metà` (correzione).

---

## 2. Rospo Gigante — rimossa una riga orfana

In fondo alla voce `\mostro{Rospo Gigante}` c'era una riga `Colpisce:` che non corrispondeva ad alcun attacco della voce (il Morso infligge `7 (1d10 + 2) perforanti più 5 (1d10) veleno`, l'Inghiottire `10 (3d6) acido`).

**PRIMA** (chiusura della voce):

```
Se il rospo muore, una creatura inghiottita non è più intralciata da esso e può uscire dal cadavere utilizzando 1 metro di movimento, uscendo prono.

\emph{Colpisce:} 8 (2d4 + 3) danni contundenti.
```

**DOPO**:

```
Se il rospo muore, una creatura inghiottita non è più intralciata da esso e può uscire dal cadavere utilizzando 1 metro di movimento, uscendo prona.
```

Altre modifiche alla voce: `una attacco` → `un attacco`, `all'esterno della rana` → `all'esterno del rospo`, `uscendo prono` → `uscendo prona` (correzioni).

---

## 3. Incantesimo — rimossa una frase identica duplicata

La frase sui Successi Critici Magici era presente due volte identiche nello stesso incantesimo.

**PRIMA**:

```
\textbf{Per ogni Successo Critico Magico} ottenuto nella Prova di Magia la durata raddoppia o togli un mese dal conteggio per renderlo permanente.

\textbf{NOTA}: l'incantesimo lanciato per un anno tutti i giorni sempre nello stesso luogo diventa permanente.

\textbf{Per ogni Successo Critico Magico} ottenuto nella Prova di Magia la durata raddoppia o togli un mese dal conteggio per renderlo permanente.
```

**DOPO**:

```
\textbf{Per ogni Successo Critico Magico} ottenuto nella Prova di Magia la durata raddoppia o togli un mese dal conteggio per renderlo permanente.

\textbf{NOTA}: l'incantesimo lanciato per un anno tutti i giorni sempre nello stesso luogo diventa permanente.
```

---

## 4. Lista delle Spade — rimossa una parola duplicata

Nella lista dell'elenco armi "Spade", `Spada a due lame` compariva due volte.

**PRIMA**:

```
\subsection{Spade}\index{Spade} Spada Corta, Spada Lunga, Spadone a due mani, Spada bastarda, Spada a due lame, Spada larga, Spada a due lame, Estoc
```

**DOPO**:

```
\subsection{Spade}\index{Spade} Spada Corta, Spada Lunga, Spadone a due mani, Spada bastarda, Spada a due lame, Spada larga, Estoc
```

---

## 5. Abilità — rimosso un doppione

L'originale ripeteva "prendi questa Abilità" due volte.

**PRIMA**:

```
La \textbf{prima volta} che prendi questa Abilità quando prendi questa Abilità aumenti di 1d6 i Punti Ferita.
```

**DOPO**:

```
La \textbf{prima volta} che prendi questa Abilità aumenti di 1d6 i Punti Ferita.
```

---

## 6. Riformulazione — riga 2607 (origini del personaggio)

Frase riscritta: corretti punteggiatura, maiuscole e scorrevolezza. Nessun contenuto perso.

**PRIMA**:

```
È cresciuto in famiglia, in un clan, vagabondo, per strada.. cosa l'ha portato e che scelte ha fatto per arrivare fino ad adesso ?
```

**DOPO**:

```
È cresciuto in famiglia, in un clan, da vagabondo o per strada... Cosa l'ha portato fin qui e quali scelte ha fatto?
```

---

## 7. Riformulazione — riga 4413 (attraversare i nemici)

Ordine delle parole riordinato per scorrevolezza. Nessun contenuto perso.

**PRIMA**:

```
Costa 1 Azione (Riflessi) la prova per attraversare, indipendentemente dal numero di creature, oltre all'Azione di Movimento.
```

**DOPO**:

```
La prova per attraversare costa 1 Azione (Riflessi), indipendentemente dal numero di creature, oltre all'Azione di Movimento.
```

---

*Nota: i numeri di riga si riferiscono al file attuale; nell'originale le posizioni possono differire di qualche riga.*
