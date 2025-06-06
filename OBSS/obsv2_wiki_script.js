#!/usr/bin/env node

/**
 * OBSSv2 Wiki Uploader
 * 
 * Script per automatizzare il caricamento dei file Markdown OBSSv2 sulla wiki di GitHub
 * 
 * @author Andres Zanzani
 * @license GPL-3.0
 * @version 1.0.0
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
                    sections.push({
                        title: currentSection,
                        content: currentContent.join('\n').trim()
                    });
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
            sections.push({
                title: currentSection,
                content: currentContent.join('\n').trim()
            });
        }

        return sections;
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
            await fs.rmdir(this.wikiDir, { recursive: true });
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
        
        try {
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

        // Crea i collegamenti alle sezioni
        sections.forEach((section, index) => {
            const sectionFile = sectionFiles[index];
            if (sectionFile) {
                indexContent += `- [${section.title}](${sectionFile})\n`;
            } else {
                indexContent += `- ${section.title} (errore nel caricamento)\n`;
            }
        });

        indexContent += `\n---\n`;
        indexContent += isItalian 
            ? `*Generato automaticamente il ${new Date().toLocaleString('it-IT')}*`
            : `*Generated automatically on ${new Date().toLocaleString('en-US')}*`;

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
        
        // Crea la voce per oggi
        const todayEntry = `- ${this.today} - [OBSSv2](${this.today}-OBSSv2)\n- ${this.today} - [OBSSv2-eng](${this.today}-OBSSv2-eng)\n`;

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
                // Ignora errori di configurazione git
            }
            
            await this.executeCommand('git add .', options);
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
            await fs.rmdir(this.wikiDir, { recursive: true });
            console.log('✓ File temporanei rimossi');
        } catch (error) {
            console.warn('⚠️  Impossibile rimuovere file temporanei:', error.message);
        }
    }

    async processFile(filename, language) {
        console.log(`\n📁 Elaborazione ${filename}...`);
        
        const content = await this.readMarkdownFile(filename);
        if (!content) return [];

        const sections = this.splitIntoSections(content);
        console.log(`📋 Trovate ${sections.length} sezioni`);

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
        
        try {
            await this.loadToken();
            await this.setupWikiRepo();

            const indexPages = [];

            // Elabora file italiano
            const itaFiles = await this.processFile('OBSSv2.md', 'ita');
            if (itaFiles.length > 0) {
                indexPages.push(`${this.today}-OBSSv2`);
            }
            
            // Elabora file inglese
            const engFiles = await this.processFile('OBSSv2-eng.md', 'eng');
            if (engFiles.length > 0) {
                indexPages.push(`${this.today}-OBSSv2-eng`);
            }
            
            // Aggiorna la pagina Home con i nuovi caricamenti
            if (indexPages.length > 0) {
                await this.updateHomePage(indexPages);
            }
            
            // Carica tutto sulla wiki
            await this.commitAndPush();
            
            console.log('\n✅ Script completato con successo!');
            console.log(`🌐 Controlla la wiki su: https://github.com/buzzqw/TUS/wiki`);
            console.log(`🏠 La pagina Home è stata aggiornata con i collegamenti a:`);
            indexPages.forEach(page => {
                console.log(`   - ${page}`);
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
    
    if (args.includes('--clean') || args.includes('-c')) {
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
