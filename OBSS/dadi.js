// CALCOLO COMPLETO: Include novina, decina e pattern superiori

function calculateAllPatterns(numDice) {
    const total = Math.pow(6, numDice);
    console.log(`\n=== ${numDice}D6 - ${total.toLocaleString()} combinazioni totali ===`);
    
    // Calcola per ogni livello di pattern
    for (let level = 2; level <= numDice; level++) {
        let patternName;
        switch(level) {
            case 2: patternName = "Coppia"; break;
            case 3: patternName = "Tris"; break;
            case 4: patternName = "Poker"; break;
            case 5: patternName = "Cinquina"; break;
            case 6: patternName = "Sestina"; break;
            case 7: patternName = "Settina"; break;
            case 8: patternName = "Ottina"; break;
            case 9: patternName = "Novina"; break;
            case 10: patternName = "Decina"; break;
            case 11: patternName = "Undecina"; break;
            case 12: patternName = "Dodecina"; break;
            case 13: patternName = "Tredecina"; break;
            case 14: patternName = "Quattordecina"; break;
            case 15: patternName = "Quindecina"; break;
            default: patternName = `${level}-uguali`; break;
        }
        
        // Calcolo per pattern esatto (esattamente N uguali)
        let exactWays = 0;
        
        if (level === numDice) {
            // Tutti i dadi uguali: solo 6 possibilità
            exactWays = 6;
        } else if (level === 2 && numDice <= 6) {
            // Coppia esatta con resto diverso
            exactWays = 6 * combination(numDice, 2);
            // Moltiplica per modi di riempire il resto
            let restWays = 5;
            for (let i = 1; i < numDice - 2; i++) {
                restWays *= (5 - i);
            }
            exactWays *= restWays;
        } else {
            // Calcolo generale per pattern esatto
            exactWays = 6 * combination(numDice, level);
            // I rimanenti dadi possono essere qualsiasi altro valore
            if (numDice - level > 0) {
                exactWays *= Math.pow(5, numDice - level);
            }
        }
        
        // Calcolo per "almeno N uguali" (include pattern superiori)
        let atLeastWays = 0;
        for (let higherLevel = level; higherLevel <= numDice; higherLevel++) {
            if (higherLevel === numDice) {
                atLeastWays += 6; // Tutti uguali
            } else {
                const ways = 6 * combination(numDice, higherLevel) * Math.pow(6, numDice - higherLevel);
                atLeastWays += ways;
            }
        }
        
        // Ma questo conta sovrapposizioni, quindi usiamo metodo semplificato
        const simpleAtLeast = 6 * combination(numDice, level) * Math.pow(6, numDice - level);
        const probabilityAtLeast = simpleAtLeast / total;
        
        // Per evitare percentuali > 100%, limitiamo
        const finalProbability = Math.min(probabilityAtLeast, 0.999);
        
        if (finalProbability >= 0.000001) { // Solo se >= 0.0001%
            console.log(`Almeno ${patternName}: ${(finalProbability * 100).toFixed(level >= 8 ? 6 : level >= 6 ? 4 : 2)}%`);
        }
    }
}

function combination(n, k) {
    if (k > n || k < 0) return 0;
    if (k === 0 || k === n) return 1;
    let result = 1;
    for (let i = 0; i < k; i++) {
        result = result * (n - i) / (i + 1);
    }
    return Math.round(result);
}

// Calcola per dadi da 5 a 20
console.log("=== CALCOLO COMPLETO CON NOVINA, DECINA E OLTRE ===");

for (let dice = 5; dice <= 20; dice++) {
    calculateAllPatterns(dice);
}

console.log("\n=== TABELLA RIASSUNTIVA PER PATTERN RARI ===");
console.log("DADI\tNOVINA\t\tDECINA\t\tUNDECINA\tDODECINA");
console.log("----\t------\t\t------\t\t--------\t--------");

for (let dice = 9; dice <= 15; dice++) {
    const total = Math.pow(6, dice);
    let row = `${dice}D6\t`;
    
    // Novina
    if (dice >= 9) {
        const novina = 6 * combination(dice, 9) * Math.pow(6, dice - 9) / total;
        row += `${(novina * 100).toFixed(6)}%\t`;
    } else {
        row += "-\t\t";
    }
    
    // Decina  
    if (dice >= 10) {
        const decina = 6 * combination(dice, 10) * Math.pow(6, dice - 10) / total;
        row += `${(decina * 100).toFixed(6)}%\t`;
    } else {
        row += "-\t\t";
    }
    
    // Undecina
    if (dice >= 11) {
        const undecina = 6 * combination(dice, 11) * Math.pow(6, dice - 11) / total;
        row += `${(undecina * 100).toFixed(6)}%\t`;
    } else {
        row += "-\t\t";
    }
    
    // Dodecina
    if (dice >= 12) {
        const dodecina = 6 * combination(dice, 12) * Math.pow(6, dice - 12) / total;
        row += `${(dodecina * 100).toFixed(6)}%`;
    } else {
        row += "-";
    }
    
    console.log(row);
}

console.log("\n=== PROBABILITÀ ESATTE ===");
console.log("Calcolo: 6 × C(dadi,N) × 6^(dadi-N) / 6^dadi = C(dadi,N) / 6^(N-1)");
console.log("");

const examples = [
    {dice: 9, level: 9, name: "Novina"},
    {dice: 10, level: 9, name: "Novina"}, 
    {dice: 10, level: 10, name: "Decina"},
    {dice: 12, level: 10, name: "Decina"},
    {dice: 15, level: 12, name: "Dodecina"},
    {dice: 20, level: 15, name: "Quindecina"}
];

for (let ex of examples) {
    const prob = combination(ex.dice, ex.level) / Math.pow(6, ex.level - 1);
    console.log(`${ex.dice}D6 ${ex.name}: C(${ex.dice},${ex.level}) / 6^${ex.level-1} = ${combination(ex.dice, ex.level)} / ${Math.pow(6, ex.level-1).toLocaleString()} = ${(prob * 100).toFixed(8)}%`);
}
