#!/usr/bin/env node

/**
 * OBSSv2 Wiki Uploader
 * 
 * Script per automatizzare il caricamento dei file Markdown OBSSv2 sulla wiki di GitHub
 * Versione migliorata con gestione del limite di 512KB di GitHub Wiki
 * 
 * @author Andres Zanzani
 * @license GPL-3.0
 * @version 1.2.0
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

const fs = require('fs').promises;
const path = require('path');
const { execSync } = require('child_process');

class GitHubWikiUploader {
    constructor() {
        this.token = null;
        this.repoUrl = 'https://github.com/buzzqw/TUS.wiki.git';
        this.wikiDir = './wiki-temp';
        this.today = new Date().toISOString().split('T')[0]; // Format: YYYY-MM-DD
        this.MAX_FILE_SIZE = 500 * 1024; // 500KB per sicurezza (GitHub ha limite a 512KB)
    }

    showHelp() {
        console.log(`
🚀 OBSSv2 Wiki Uploader v1.2.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 DESCRIZIONE:
   Script per automatizzare il caricamento dei file Markdown OBSSv2 sulla wiki di GitHub.
   Elabora i file OBSSv2.md (italiano) e OBSSv2-eng.md (inglese), divide ogni file
   in sezioni basate sui titoli di primo livello (# Titolo) e carica ogni sezione
   come pagina separata sulla wiki.
   
   ✨ NOVITÀ v1.2.0: Gestione automatica del limite di 512KB di GitHub Wiki!
   Le sezioni troppo grandi vengono automaticamente divise in più parti.

🔧 USO:
   node obsv2_wiki_script.js [opzioni]

📋 OPZIONI:
   (nessuna)           Modalità normale - elabora e carica i file OBSSv2
   -c, --clean        Modalità pulizia - rimuove tutti i file dalla wiki
   -h, --help         Mostra questo messaggio di aiuto

📁 FILE RICHIESTI:
   • .token           File contenente il token GitHub (formato: githubtoken=TOKEN)
   • OBSSv2.md        File Markdown in italiano (opzionale)
   • OBSSv2-eng.md    File Markdown in inglese (opzionale)

⚙️  CONFIGURAZIONE:
   1. Crea un file .token nella stessa directory dello script
   2. Inserisci nel file: githubtoken=IL_TUO_TOKEN_GITHUB
   3. Assicurati che il token abbia i permessi per modificare la wiki

📤 COSA FA IN MODALITÀ NORMALE:
   • Legge i file OBSSv2.md e OBSSv2-eng.md
   • Divide ogni file in sezioni basate sui titoli # (livello 1)
   • Divide automaticamente le sezioni > 500KB in più parti
   • Crea una pagina wiki separata per ogni sezione/sottosezione
   • Genera pagine indice per ciascuna lingua
   • Aggiorna la pagina Home con i collegamenti ai nuovi caricamenti
   • Effettua commit e push sulla repository wiki

🧹 COSA FA IN MODALITÀ PULIZIA:
   • Rimuove TUTTI i file dalla wiki
   • Crea una nuova pagina Home pulita
   • Effettua commit e push delle modifiche

📏 GESTIONE LIMITI GITHUB:
   • GitHub Wiki ha un limite di 512KB per file
   • Le sezioni che superano 500KB vengono automaticamente divise
   • Ogni parte mantiene il titolo originale + numero parte
   • L'indice mostra chiaramente le sezioni divise

📋 ESEMPI:
   # Caricamento normale
   node obsv2_wiki_script.js

   # Pulizia completa della wiki
   node obsv2_wiki_script.js --clean

   # Mostra aiuto
   node obsv2_wiki_script.js --help

⚠️  NOTE IMPORTANTI:
   • La modalità --clean elimina PERMANENTEMENTE tutti i contenuti della wiki
   • Assicurati di avere backup prima di usare --clean
   • Il token GitHub deve avere permessi di scrittura sulla repository
   • I file vengono organizzati per data (formato: YYYY-MM-DD)
   • Le sezioni molto grandi vengono divise automaticamente

🌐 REPOSITORY WIKI: https://github.com/buzzqw/TUS/wiki

📄 LICENZA: GPL-3.0
👤 AUTORE: Andres Zanzani
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
`);
    }

    async loadToken() {
        try {
            const tokenFile = await fs.readFile('.token', 'utf8');
            const tokenMatch = tokenFile.match(/githubtoken=(.+)/);
            if (tokenMatch) {
                this.token = tokenMatch[1].trim();
                console.log('✓ Token caricato correttamente');
            } else {
                throw new Error('Token non trovato nel file .token');
            }
        } catch (error) {
            console.error('Errore nel caricamento del token:', error.message);
            process.exit(1);
        }
    }

    async readMarkdownFile(filename) {
        try {
            const content = await fs.readFile(filename, 'utf8');
            console.log(`✓ File ${filename} letto correttamente`);
            return content;
        } catch (error) {
            console.error(`Errore nella lettura di ${filename}:`, error.message);
            return null;
        }
    }

    splitIntoSections(content) {
        const lines = content.split('\n');
        const sections = [];
        let currentSection = null;
        let currentContent = [];

        for (const line of lines) {
            // Controlla se la riga è un header di primo livello (# titolo)
            if (line.match(/^# [^#]/)) {
                // Salva la sezione precedente se esiste
                if (currentSection) {
                    const sectionContent = currentContent.join('\n').trim();
                    const processedSections = this.splitLargeSections({
                        title: currentSection,
                        content: sectionContent
                    });
                    sections.push(...processedSections);
                }
                
                // Inizia una nuova sezione
                currentSection = line.substring(2).trim(); // Rimuove "# "
                currentContent = [line]; // Include l'header nella sezione
            } else {
                if (currentSection) {
                    currentContent.push(line);
                }
            }
        }

        // Aggiungi l'ultima sezione
        if (currentSection) {
            const sectionContent = currentContent.join('\n').trim();
            const processedSections = this.splitLargeSections({
                title: currentSection,
                content: sectionContent
            });
            sections.push(...processedSections);
        }

        return sections;
    }

    // Nuovo metodo per dividere sezioni troppo grandi
    splitLargeSections(section) {
        const contentSize = Buffer.byteLength(section.content, 'utf8');
        
        // Se la sezione è sotto il limite, restituiscila così com'è
        if (contentSize <= this.MAX_FILE_SIZE) {
            console.log(`📄 Sezione "${section.title}": ${contentSize} byte (OK)`);
            return [section];
        }

        console.log(`⚠️  Sezione "${section.title}": ${contentSize} byte (TROPPO GRANDE, divisione necessaria)`);
        
        const lines = section.content.split('\n');
        const subsections = [];
        let currentSubsection = [];
        let currentSize = 0;
        let partNumber = 1;
        let headerAdded = false;

        for (const line of lines) {
            const lineSize = Buffer.byteLength(line + '\n', 'utf8');
            
            // Se aggiungendo questa riga supereremmo il limite e abbiamo già del contenuto
            if (currentSize + lineSize > this.MAX_FILE_SIZE && currentSubsection.length > 0) {
                // Salva la sottosezione corrente
                const subsectionTitle = partNumber === 1 ? 
                    section.title : 
                    `${section.title} (Parte ${partNumber})`;
                
                subsections.push({
                    title: subsectionTitle,
                    content: currentSubsection.join('\n').trim()
                });
                
                console.log(`📝 Creata sottosezione: "${subsectionTitle}" (${currentSize} byte)`);
                
                // Inizia una nuova sottosezione
                partNumber++;
                currentSubsection = [];
                currentSize = 0;
                headerAdded = false;
            }
            
            // Aggiungi l'header della sezione originale alla prima riga di ogni sottosezione
            if (!headerAdded && !line.match(/^# /) && partNumber > 1) {
                const originalHeader = `# ${section.title} (Parte ${partNumber})`;
                currentSubsection.push(originalHeader);
                currentSubsection.push(''); // Riga vuota dopo l'header
                currentSize += Buffer.byteLength(originalHeader + '\n\n', 'utf8');
                headerAdded = true;
            }
            
            currentSubsection.push(line);
            currentSize += lineSize;
        }

        // Aggiungi l'ultima sottosezione se ha contenuto
        if (currentSubsection.length > 0) {
            const subsectionTitle = partNumber === 1 ? 
                section.title : 
                `${section.title} (Parte ${partNumber})`;
            
            subsections.push({
                title: subsectionTitle,
                content: currentSubsection.join('\n').trim()
            });
            
            console.log(`📝 Creata sottosezione finale: "${subsectionTitle}" (${currentSize} byte)`);
        }

        console.log(`✅ Sezione "${section.title}" divisa in ${subsections.length} parti`);
        return subsections;
    }

    sanitizeFileName(title) {
        // Rimuove caratteri non validi per nomi di file e GitHub Wiki
        return title
            .replace(/[^a-zA-Z0-9\s-]/g, '')
            .replace(/\s+/g, '-')
            .replace(/--+/g, '-')
            .replace(/^-|-$/g, '')
            .substring(0, 100); // Limita lunghezza
    }

    async executeCommand(command, options = {}) {
        try {
            const result = execSync(command, { 
                encoding: 'utf8', 
                stdio: 'pipe',
                ...options 
            });
            return result.trim();
        } catch (error) {
            throw new Error(`Comando fallito: ${command}\nErrore: ${error.message}`);
        }
    }

    async setupWikiRepo() {
        console.log('📁 Configurazione repository wiki...');
        
        // Rimuovi directory esistente se presente
        try {
            await fs.rm(this.wikiDir, { recursive: true, force: true });
        } catch (error) {
            // Ignora errore se la directory non esiste
        }

        // Clona la wiki
        const cloneUrl = this.repoUrl.replace('https://', `https://${this.token}@`);
        await this.executeCommand(`git clone ${cloneUrl} ${this.wikiDir}`);
        
        console.log('✓ Repository wiki clonata');
    }

    async createWikiFile(filename, content) {
        const filePath = path.join(this.wikiDir, `${filename}.md`);
        const contentSize = Buffer.byteLength(content, 'utf8');
        
        // Controllo preventivo della dimensione
        if (contentSize > this.MAX_FILE_SIZE) {
            console.error(`❌ File ${filename}.md troppo grande: ${contentSize} byte (limite: ${this.MAX_FILE_SIZE} byte)`);
            return false;
        }
        
        try {
            console.log(`📊 Creazione file ${filename}.md (${contentSize} byte)`);
            await fs.writeFile(filePath, content, 'utf8');
            console.log(`✓ File creato: ${filename}.md`);
            return true;
        } catch (error) {
            console.error(`✗ Errore nella creazione del file ${filename}:`, error.message);
            return false;
        }
    }

    async createIndexPage(language, sections, sectionFiles) {
        const isItalian = language === 'ita';
        const fileName = `${this.today}-OBSSv2${isItalian ? '' : '-eng'}`;
        const pageTitle = `OBSSv2 - ${this.today}${isItalian ? '' : ' (English)'}`;
        
        let indexContent = `# ${pageTitle}\n\n`;
        indexContent += isItalian 
            ? `Indice delle sezioni caricate il ${this.today}:\n\n`
            : `Index of sections uploaded on ${this.today}:\n\n`;

        // Raggruppa le sezioni per titolo base (per gestire le parti)
        const groupedSections = new Map();
        sections.forEach((section, index) => {
            const baseTitle = section.title.replace(/ \(Parte \d+\)$/, '');
            const partMatch = section.title.match(/\(Parte (\d+)\)$/);
            
            if (!groupedSections.has(baseTitle)) {
                groupedSections.set(baseTitle, []);
            }
            
            groupedSections.get(baseTitle).push({
                section,
                index,
                partNumber: partMatch ? parseInt(partMatch[1]) : 1
            });
        });

        // Crea i collegamenti alle sezioni
        for (const [baseTitle, parts] of groupedSections) {
            if (parts.length === 1) {
                // Sezione singola
                const { section, index } = parts[0];
                const sectionFile = sectionFiles[index];
                if (sectionFile) {
                    indexContent += `- [${section.title}](${sectionFile})\n`;
                } else {
                    indexContent += `- ${section.title} ${isItalian ? '(errore nel caricamento)' : '(upload error)'}\n`;
                }
            } else {
                // Sezione divisa in parti
                indexContent += `- **${baseTitle}**\n`;
                parts.sort((a, b) => a.partNumber - b.partNumber);
                parts.forEach(({ section, index, partNumber }) => {
                    const sectionFile = sectionFiles[index];
                    if (sectionFile) {
                        indexContent += `  - [Parte ${partNumber}](${sectionFile})\n`;
                    } else {
                        indexContent += `  - Parte ${partNumber} ${isItalian ? '(errore nel caricamento)' : '(upload error)'}\n`;
                    }
                });
            }
        }

        indexContent += `\n---\n`;
        indexContent += isItalian 
            ? `*Generato automaticamente il ${new Date().toLocaleString('it-IT')}*\n`
            : `*Generated automatically on ${new Date().toLocaleString('en-US')}*\n`;
        
        indexContent += `\n${isItalian ? '**Nota**: Le sezioni molto grandi sono state automaticamente divise in più parti per rispettare i limiti di GitHub Wiki (512KB).' : '**Note**: Very large sections have been automatically split into multiple parts to comply with GitHub Wiki limits (512KB).'}`;

        const success = await this.createWikiFile(fileName, indexContent);
        if (success) {
            console.log(`✓ Pagina indice creata: ${fileName}.md`);
        }
        
        return fileName;
    }

    async updateHomePage(indexPages) {
        console.log('🏠 Aggiornamento pagina Home...');
        
        const homeFile = path.join(this.wikiDir, 'Home.md');
        let homeContent = '';
        
        // Leggi il contenuto esistente se presente
        try {
            homeContent = await fs.readFile(homeFile, 'utf8');
        } catch (error) {
            // Se non esiste, crea una nuova Home page
            homeContent = '# Wiki TUS\n\nBenvenuto nella wiki del progetto TUS.\n\n';
        }

        // Cerca se esiste già una sezione per OBSSv2
        const obssSectionRegex = /## OBSSv2 - Wiki[\s\S]*?(?=\n##|\n---|\n$|$)/;
        const obssSectionMatch = homeContent.match(obssSectionRegex);
        
        // Crea le voci per oggi
        let todayEntry = '';
        indexPages.forEach(page => {
            const isEng = page.includes('-eng');
            const label = isEng ? 'OBSSv2 (English)' : 'OBSSv2 (Italiano)';
            todayEntry += `- ${this.today} - [${label}](${page})\n`;
        });

        if (obssSectionMatch) {
            // Se esiste già una sezione OBSSv2, aggiungi in cima (più recente prima)
            const existingSection = obssSectionMatch[0];
            const newSection = existingSection.replace(
                '## OBSSv2 - Wiki\n\n',
                `## OBSSv2 - Wiki\n\n${todayEntry}`
            );
            homeContent = homeContent.replace(obssSectionRegex, newSection);
        } else {
            // Se non esiste una sezione OBSSv2, aggiungila alla fine
            if (!homeContent.endsWith('\n\n')) {
                homeContent += homeContent.endsWith('\n') ? '\n' : '\n\n';
            }
            homeContent += `## OBSSv2 - Wiki\n\n${todayEntry}`;
        }

        // Scrivi il file Home aggiornato
        try {
            await fs.writeFile(homeFile, homeContent, 'utf8');
            console.log('✓ Pagina Home aggiornata con i caricamenti del giorno');
        } catch (error) {
            console.error('✗ Errore nell\'aggiornamento della pagina Home:', error.message);
        }
    }

    async cleanWiki() {
        console.log('🧹 Pulizia completa della wiki...');
        
        try {
            await this.setupWikiRepo();
            
            // Leggi tutti i file nella directory wiki
            const files = await fs.readdir(this.wikiDir);
            const markdownFiles = files.filter(file => file.endsWith('.md'));
            
            console.log(`📄 Trovati ${markdownFiles.length} file da rimuovere...`);
            
            // Rimuovi tutti i file markdown
            for (const file of markdownFiles) {
                const filePath = path.join(this.wikiDir, file);
                await fs.unlink(filePath);
                console.log(`🗑️  Rimosso: ${file}`);
            }
            
            // Crea una nuova Home page pulita
            const newHomeContent = `# Wiki TUS

Benvenuto nella wiki del progetto TUS.

`;
            await fs.writeFile(path.join(this.wikiDir, 'Home.md'), newHomeContent, 'utf8');
            console.log('✓ Creata nuova Home page pulita');
            
            // Commit e push delle modifiche
            const options = { cwd: this.wikiDir };
            
            try {
                await this.executeCommand('git config user.email "obsv2-uploader@example.com"', options);
                await this.executeCommand('git config user.name "OBSSv2 Uploader"', options);
            } catch (error) {
                // Ignora errori di configurazione git se già configurati
                console.log('ℹ️  Configurazione git già presente');
            }
            
            await this.executeCommand('git add .', options);
            
            // Verifica se ci sono modifiche da committare
            try {
                const status = await this.executeCommand('git status --porcelain', options);
                if (!status) {
                    console.log('ℹ️  La wiki è già pulita, nessuna modifica necessaria');
                    return;
                }
            } catch (error) {
                // Continua comunque
            }
            
            await this.executeCommand('git commit -m "Pulizia completa della wiki"', options);
            await this.executeCommand('git push origin master', options);
            
            console.log('✅ Wiki pulita con successo!');
            
        } catch (error) {
            console.error('❌ Errore durante la pulizia:', error.message);
            throw error;
        } finally {
            await this.cleanup();
        }
    }

    async commitAndPush() {
        console.log('📤 Commit e push delle modifiche...');
        
        const options = { cwd: this.wikiDir };
        
        // Configura git se necessario
        try {
            await this.executeCommand('git config user.email "obsv2-uploader@example.com"', options);
            await this.executeCommand('git config user.name "OBSSv2 Uploader"', options);
        } catch (error) {
            // Ignora errori di configurazione git
        }

        // Aggiungi tutti i file
        await this.executeCommand('git add .', options);
        
        // Verifica se ci sono modifiche da committare
        try {
            const status = await this.executeCommand('git status --porcelain', options);
            if (!status) {
                console.log('⚠️  Nessuna modifica da committare');
                return;
            }
        } catch (error) {
            // Continua comunque
        }

        // Commit
        const commitMessage = `Upload OBSSv2 sections - ${this.today}`;
        await this.executeCommand(`git commit -m "${commitMessage}"`, options);
        
        // Push
        await this.executeCommand('git push origin master', options);
        
        console.log('✓ Modifiche caricate sulla wiki');
    }

    async cleanup() {
        try {
            await fs.rm(this.wikiDir, { recursive: true, force: true });
            console.log('✓ File temporanei rimossi');
        } catch (error) {
            console.warn('⚠️  Impossibile rimuovere file temporanei:', error.message);
        }
    }

    async processFile(filename, language) {
        console.log(`\n📁 Elaborazione ${filename}...`);
        
        const content = await this.readMarkdownFile(filename);
        if (!content) {
            console.log(`⚠️  File ${filename} non trovato o non leggibile`);
            return [];
        }

        const sections = this.splitIntoSections(content);
        console.log(`📋 Trovate ${sections.length} sezioni (incluse eventuali suddivisioni)`);

        if (sections.length === 0) {
            console.log('⚠️  Nessuna sezione trovata (# header)');
            return [];
        }

        const sectionFiles = [];
        
        // Crea file per ogni sezione
        for (let i = 0; i < sections.length; i++) {
            const section = sections[i];
            console.log(`📝 Creazione file ${i + 1}/${sections.length}: ${section.title}`);
            
            const sanitizedTitle = this.sanitizeFileName(section.title);
            const fileName = `${this.today}-${sanitizedTitle}${language === 'eng' ? '-eng' : ''}`;
            
            const success = await this.createWikiFile(fileName, section.content);
            sectionFiles.push(success ? fileName : null);
        }

        // Crea la pagina indice
        console.log('📝 Creazione pagina indice...');
        await this.createIndexPage(language, sections, sectionFiles);
        
        return sectionFiles;
    }

    async run() {
        console.log('🚀 Avvio script per caricamento OBSSv2 su GitHub Wiki');
        console.log(`📅 Data odierna: ${this.today}`);
        console.log(`📏 Limite file: ${this.MAX_FILE_SIZE} byte (GitHub Wiki: 512KB)`);
        
        try {
            await this.loadToken();
            await this.setupWikiRepo();

            const indexPages = [];

            // Elabora file italiano
            console.log('\n=== ELABORAZIONE FILE ITALIANO ===');
            const itaFiles = await this.processFile('OBSSv2.md', 'ita');
            if (itaFiles.length > 0) {
                indexPages.push(`${this.today}-OBSSv2`);
                console.log('✓ File italiano elaborato con successo');
            } else {
                console.log('⚠️  Nessun file italiano da elaborare');
            }
            
            // Elabora file inglese
            console.log('\n=== ELABORAZIONE FILE INGLESE ===');
            const engFiles = await this.processFile('OBSSv2-eng.md', 'eng');
            if (engFiles.length > 0) {
                indexPages.push(`${this.today}-OBSSv2-eng`);
                console.log('✓ File inglese elaborato con successo');
            } else {
                console.log('⚠️  Nessun file inglese da elaborare');
            }
            
            // Aggiorna la pagina Home con i nuovi caricamenti
            if (indexPages.length > 0) {
                console.log('\n=== AGGIORNAMENTO HOME PAGE ===');
                await this.updateHomePage(indexPages);
            } else {
                console.log('⚠️  Nessun file da caricare, Home page non aggiornata');
                return;
            }
            
            // Carica tutto sulla wiki
            console.log('\n=== CARICAMENTO SU GITHUB ===');
            await this.commitAndPush();
            
            console.log('\n✅ Script completato con successo!');
            console.log(`🌐 Controlla la wiki su: https://github.com/buzzqw/TUS/wiki`);
            console.log(`🏠 La pagina Home è stata aggiornata con i collegamenti a:`);
            indexPages.forEach(page => {
                const isEng = page.includes('-eng');
                const lang = isEng ? '(English)' : '(Italiano)';
                console.log(`   - ${page} ${lang}`);
            });
            
        } catch (error) {
            console.error('❌ Errore durante l\'esecuzione:', error.message);
            throw error;
        } finally {
            await this.cleanup();
        }
    }
}

// Esecuzione dello script
if (require.main === module) {
    const uploader = new GitHubWikiUploader();
    
    // Controlla argomenti da riga di comando
    const args = process.argv.slice(2);
    
    if (args.includes('--help') || args.includes('-h') || args.includes('--h')) {
        // Modalità aiuto
        uploader.showHelp();
    } else if (args.includes('--clean') || args.includes('-c')) {
        // Modalità pulizia
        console.log('🧹 Modalità pulizia attivata');
        uploader.loadToken()
            .then(() => uploader.cleanWiki())
            .catch(error => {
                console.error('❌ Errore durante la pulizia:', error.message);
                process.exit(1);
            });
    } else {
        // Modalità normale
        uploader.run().catch(error => {
            console.error('❌ Errore fatale:', error.message);
            process.exit(1);
        });
    }
}

module.exports = GitHubWikiUploader;
