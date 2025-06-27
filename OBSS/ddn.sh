/*
 * Latex2MarkDown - LaTeX to Markdown Converter
 * 
 * Author: Andres Zanzani
 * License: GPL-3.0-or-later
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
 * 
 * NOTE: This software has been tested only on the LaTeX source files
 * found in this specific repository. It may not work correctly with
 * other LaTeX documents that use different commands or structures.
 */

import java.io.*;
import java.nio.file.*;
import java.util.regex.*;

public class Latex2MarkDown {
    
    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java Latex2MarkDown input.tex [output.md]");
            System.exit(1);
        }
        
        String inputFile = args[0];
        String outputFile = args.length > 1 ? args[1] : null;
        
        try {
            String content = Files.readString(Paths.get(inputFile));
            String converted = convertLatexToMarkdown(content);
            
            if (outputFile != null) {
                // Force Unix line endings
                String finalContent = converted.replaceAll("\\r\\n", "\n").replaceAll("\\r", "\n");
                Files.writeString(Paths.get(outputFile), finalContent);
                System.out.println("=== SUCCESS: File written to " + outputFile + " ===");
            } else {
                System.out.println(converted);
            }
        } catch (IOException e) {
            System.err.println("Error: " + e.getMessage());
            System.exit(1);
        }
    }
    
    public static String convertLatexToMarkdown(String content) {
        // Normalize line endings
        content = content.replaceAll("\\r\\n?", "\n");
        
        // Remove everything before \begin{document}
        int documentStart = content.indexOf("\\begin{document}");
        if (documentStart != -1) {
            content = content.substring(documentStart + "\\begin{document}".length());
        }

        // Handle multirow FIRST - remove it but keep the content
        content = content.replaceAll("\\\\multirow\\{[^}]*\\}\\*?\\{([^}]*)\\}", "$1");
        
        // Handle multicolumn FIRST, before any other text processing
        Pattern multicolPattern = Pattern.compile("\\\\multicolumn\\{([0-9]+)\\}\\{[^}]*\\}\\{([^\\\\]*)\\\\textbf\\{([^}]+)\\}([^\\\\]*)\\}");
        Matcher multicolMatcher = multicolPattern.matcher(content);
        StringBuffer sb_multicol = new StringBuffer();
        while (multicolMatcher.find()) {
            int colSpan = Integer.parseInt(multicolMatcher.group(1));
            String beforeTextbf = multicolMatcher.group(2);
            String textbfContent = multicolMatcher.group(3);
            String afterTextbf = multicolMatcher.group(4);
            
            // Build replacement: content followed by & separators for additional columns
            StringBuilder replacement = new StringBuilder();
            replacement.append(beforeTextbf).append("\\textbf{").append(textbfContent).append("}").append(afterTextbf);
            for (int i = 1; i < colSpan; i++) {
                replacement.append(" & ");
            }
            
            multicolMatcher.appendReplacement(sb_multicol, Matcher.quoteReplacement(replacement.toString()));
        }
        multicolMatcher.appendTail(sb_multicol);
        content = sb_multicol.toString();
        
        // Handle simpler multicolumn cases without textbf
        Pattern simpleMulticolPattern = Pattern.compile("\\\\multicolumn\\{([0-9]+)\\}\\{[^}]*\\}\\{([^}]+)\\}");
        Matcher simpleMulticolMatcher = simpleMulticolPattern.matcher(content);
        StringBuffer sb_multicol2 = new StringBuffer();
        while (simpleMulticolMatcher.find()) {
            int colSpan = Integer.parseInt(simpleMulticolMatcher.group(1));
            String multicolContent = simpleMulticolMatcher.group(2);
            
            // Build replacement: content followed by & separators for additional columns
            StringBuilder replacement = new StringBuilder(multicolContent);
            for (int i = 1; i < colSpan; i++) {
                replacement.append(" & ");
            }
            
            simpleMulticolMatcher.appendReplacement(sb_multicol2, Matcher.quoteReplacement(replacement.toString()));
        }
        simpleMulticolMatcher.appendTail(sb_multicol2);
        content = sb_multicol2.toString();
        
        // Apply all transformations
        content = applyShellScriptFixes(content);
        content = handlePageBreaks(content);
        content = removeComments(content);
        content = handleSectionHeadings(content);
        content = removeLaTeXCommands(content);
        content = handleBoxEnvironments(content);
        content = handleTables(content);
        content = handleTextFormatting(content);
        content = addTableSeparators(content);
        content = handleSpecialTables(content);
        content = finalCleanup(content);
        
        // Remove everything after \end{document}
        int documentEnd = content.indexOf("\\end{document}");
        if (documentEnd != -1) {
            content = content.substring(0, documentEnd);
        }
        
        // Remove excessive whitespace
        content = content.replaceAll("\n{3,}", "\n\n");
        content = content.trim();
        
        return content;
    }
    
    private static String applyShellScriptFixes(String content) {
        // Remove \cline commands
        content = content.replaceAll("\\\\cline\\{[^}]*\\}", "");
        
        // Replace main title
        content = content.replaceAll("Old Bell School System", "**Old Bell School System - OBSS - Fantasy Adventure Game**");
        
        // Fix D&D references
        content = content.replaceAll("D \\| D", "D&D");
        
        // Remove page references
        content = content.replaceAll("\\(pag\\. \\)", "");
        
        // Remove \cmidrule commands
        content = content.replaceAll("\\\\cmidrule\\(lr\\)", "");
        
        // Remove box narratore comments
        content = content.replaceAll("%box narratore", "");
        
        // Fix bold formatting
        content = content.replaceAll("'\\*\\*", "' **");
        
        // Remove \hskip commands
        content = content.replaceAll("\\\\hskip 0\\.5cm", "");
        
        return content;
    }
    
    private static String handlePageBreaks(String content) {
        // Handle page breaks - convert to markdown page separators with proper spacing
        content = content.replaceAll("\\\\pagebreak(?:\\s*~)?", "\n\n---\n\n");
        content = content.replaceAll("\\\\newpage(?:\\s*~)?", "\n\n---\n\n");
        
        // Ensure page breaks always have proper spacing
        content = content.replaceAll("([^\\n\\s])\\s*\\n\\s*---\\s*\\n", "$1\n\n---\n\n");
        content = content.replaceAll("\\n\\s*---\\s*\\n([^\\n\\s])", "\n\n---\n\n$1");
        content = content.replaceAll("([^\\n])---", "$1\n\n---");
        content = content.replaceAll("---([^\\n])", "---\n\n$1");
        
        return content;
    }
    
    private static String removeComments(String content) {
        // Remove comments AFTER multicolumn processing
        content = content.replaceAll("(?m)^\\s*%.*$", "");
        return content;
    }
    
    private static String handleSectionHeadings(String content) {
        // Extract spell/ability names from headers
        Pattern spellHeaderPattern = Pattern.compile(
            "\\\\smallskip\\\\noindent\\\\rule\\{[^}]+\\}\\{[^}]+\\}[^\\n]*\\\\textbf\\{([^}]+)\\}[^\\n]*", 
            Pattern.DOTALL
        );
        Matcher spellMatcher = spellHeaderPattern.matcher(content);
        StringBuffer sb = new StringBuffer();
        while (spellMatcher.find()) {
            spellMatcher.appendReplacement(sb, Matcher.quoteReplacement("\n\n## " + spellMatcher.group(1) + "\n"));
        }
        spellMatcher.appendTail(sb);
        content = sb.toString();
        
        // Remove rule commands
        content = content.replaceAll("\\\\rule\\{[^}]*\\}\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\noindent\\\\rule\\{[^}]*\\}\\{[^}]*\\}", "");
        
        // Handle section headings
        content = content.replaceAll("\\\\section\\*?\\{([^}]*)\\}", "# $1");
        content = content.replaceAll("\\\\subsection\\*?\\{([^}]*)\\}", "## $1");
        content = content.replaceAll("\\\\subsubsection\\*?\\{([^}]*)\\}", "### $1");
        
        return content;
    }
    
    private static String removeLaTeXCommands(String content) {
        // Remove remaining LaTeX artifacts from headers
        content = content.replaceAll("\\\\index(?:\\[[^\\]]*\\])?\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\hypertarget\\{[^}]+\\}\\{\\}", "");
        content = content.replaceAll("\\\\pdfbookmark\\[[^\\]]*\\]\\{[^}]+\\}\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\label\\{[^}]+\\}", "");
        
        // Handle special escaped characters
        content = content.replaceAll("\\\\&", "&");
        
        // Remove figure environments completely
        content = content.replaceAll("(?s)\\\\begin\\{figure\\}.*?\\\\end\\{figure\\}", "");
        content = content.replaceAll("(?s)\\\\begin\\{center\\}.*?\\\\end\\{center\\}", "");
        content = content.replaceAll("(?s)\\\\begin\\{wrapfigure\\}[^}]*\\}.*?\\\\end\\{wrapfigure\\}", "");
        content = content.replaceAll("(?s)\\\\begin\\{minipage\\}[^}]*\\}.*?\\\\end\\{minipage\\}", "");
        content = content.replaceAll("\\\\includegraphics(?:\\[[^\\]]*\\])?\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\hspace\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\hspace", "");
        
        // Remove various LaTeX commands and artifacts
        content = content.replaceAll("\\\\(?:vfill|smallskip|medskip|bigskip|noindent)", "");
        content = content.replaceAll("\\\\titlespacing\\*\\{[^}]+\\}\\{[^}]*\\}\\{[^}]*\\}\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\stepcounter\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\newcounter\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\setlength\\{[^}]+\\}\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\columnbreak", "");
        content = content.replaceAll("\\\\small\\{?", "");
        content = content.replaceAll("\\\\normalsize", "");
        content = content.replaceAll("\\\\arraybackslash", "");
        content = content.replaceAll("\\\\centering", "");
        
        return content;
    }
    
    private static String handleBoxEnvironments(String content) {
        // enfasi boxes (simple blockquote)
        Pattern enfasiPattern = Pattern.compile(
            "\\\\begin\\{enfasi\\}\\{([^}\\\\]*)\\}\\\\end\\{enfasi\\}",
            Pattern.DOTALL
        );
        Matcher enfasiMatcher = enfasiPattern.matcher(content);
        StringBuffer sb1 = new StringBuffer();
        while (enfasiMatcher.find()) {
            String enfasiContent = enfasiMatcher.group(1).trim();
            enfasiMatcher.appendReplacement(sb1, Matcher.quoteReplacement("\n> " + enfasiContent + "\n"));
        }
        enfasiMatcher.appendTail(sb1);
        content = sb1.toString();
        
        // narratore boxes (triple blockquote)
        Pattern narratorePattern = Pattern.compile(
            "\\\\begin\\{narratore\\}([^\\\\]*)\\\\end\\{narratore\\}",
            Pattern.DOTALL
        );
        Matcher narratoreMatcher = narratorePattern.matcher(content);
        StringBuffer sb2 = new StringBuffer();
        while (narratoreMatcher.find()) {
            String narratoreContent = narratoreMatcher.group(1).trim();
            narratoreMatcher.appendReplacement(sb2, Matcher.quoteReplacement("\n>>> " + narratoreContent + "\n"));
        }
        narratoreMatcher.appendTail(sb2);
        content = sb2.toString();
        
        // tcolorbox environments
        Pattern tcolorboxPattern = Pattern.compile(
            "\\\\begin\\{tcolorbox\\}(?:\\[[^\\]]*\\])?(?:\\{([^}]*)\\})?([\\s\\S]*?)\\\\end\\{tcolorbox\\}",
            Pattern.DOTALL
        );
        Matcher tcolorboxMatcher = tcolorboxPattern.matcher(content);
        StringBuffer sb3 = new StringBuffer();
        while (tcolorboxMatcher.find()) {
            String title = tcolorboxMatcher.group(1);
            String boxContent = tcolorboxMatcher.group(2).trim();
            boxContent = boxContent.replaceAll("%[^\\n]*", "").trim();
            if (title != null && !title.isEmpty()) {
                tcolorboxMatcher.appendReplacement(sb3, Matcher.quoteReplacement("\n>> " + title + "\n>>\n>> " + boxContent + "\n"));
            } else {
                tcolorboxMatcher.appendReplacement(sb3, Matcher.quoteReplacement("\n>> " + boxContent + "\n"));
            }
        }
        tcolorboxMatcher.appendTail(sb3);
        content = sb3.toString();
        
        // Remove environment commands
        content = content.replaceAll("\\\\begin\\{(?:multicols|flushleft|flushright|changemargin|itemize|mdframed|textblock\\*)(?:[^}]*)?\\}", "");
        content = content.replaceAll("\\\\end\\{(?:multicols|flushleft|flushright|changemargin|itemize|mdframed|textblock\\*)\\}", "");
        
        return content;
    }
    
    private static String handleTables(String content) {
        // Handle tables - remove table environments
        content = content.replaceAll("\\\\begin\\{(?:tabular\\*?|tabularx|xltabular)(?:[^}]*)?\\}", "");
        content = content.replaceAll("\\\\end\\{(?:tabular\\*?|tabularx|xltabular)\\}", "");
        content = content.replaceAll("\\\\(?:toprule|midrule|bottomrule|hline)", "");
        content = content.replaceAll("\\\\cmidrule(?:\\([^)]*\\))?(?:\\[[^\\]]+\\])?\\{[^}]+\\}", "");
        
        // Convert table separators
        content = content.replaceAll("\\s*&\\s*", " | ");
        content = content.replaceAll("&\\s*\\\\\\\\", " |\n");
        content = content.replaceAll("\\s*\\\\\\\\\\s*", " |\n");
        content = content.replaceAll("\\\\\\\\", "\n");
        
        // Process table rows
        content = processTableRows(content);
        
        return content;
    }
    
    private static String processTableRows(String content) {
        String[] lines = content.split("\n");
        StringBuilder result = new StringBuilder();
        boolean inTable = false;
        boolean headerAdded = false;
        
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i].trim();
            
            if (line.contains("|") && !line.startsWith(">") && !line.startsWith("###")) {
                long pipeCount = line.chars().filter(ch -> ch == '|').count();
                
                if ((pipeCount >= 1 && (line.matches(".*\\w+:\\s*\\|.*") || 
                      line.matches(".*\\*[^*]+\\*:\\s*\\|.*"))) ||
                    (pipeCount >= 2 && line.contains("**") && 
                     (line.matches(".*\\*\\*[^*]+\\*\\*\\s*\\|.*\\*\\*[^*]+\\*\\*.*") ||
                      line.matches(".*[0-9]+\\s*\\|.*[0-9]+\\s*\\|.*") ||
                      line.matches(".*\\*\\*[^*]+\\*\\*\\s*\\|.*"))) ||
                    (pipeCount >= 1 && line.matches(".*[A-Za-z0-9].*\\|.*[A-Za-z0-9$±\\-+*].*")) ||
                    (line.matches("^[0-9]+\\s+\\|.*") || line.matches("^[0-9]+\\s.*\\|.*")) ||
                    (pipeCount >= 1 && line.matches("^[A-Za-z].*\\|.*"))) {
                    
                    if (!inTable) {
                        inTable = true;
                        headerAdded = false;
                        if (result.length() > 0 && !result.toString().endsWith("\n\n")) {
                            result.append("\n");
                        }
                    }
                    
                    if (line.matches("^[0-9]+\\s+.*\\|.*") && !line.startsWith("|")) {
                        line = "| " + line;
                    } else if (!line.startsWith("|")) {
                        line = "| " + line;
                    }
                    
                    if (!line.endsWith("|")) {
                        line = line + " |";
                    }
                    
                    result.append(line).append("\n");
                    
                    if (!headerAdded) {
                        String separator = createTableSeparator(line);
                        result.append(separator).append("\n");
                        headerAdded = true;
                    }
                } else {
                    if (line.endsWith(" |")) {
                        line = line.substring(0, line.length() - 2).trim();
                    }
                    if (inTable) {
                        inTable = false;
                        headerAdded = false;
                        result.append("\n");
                    }
                    result.append(line).append("\n");
                }
            } else {
                if (inTable && !line.isEmpty() && !line.startsWith("###")) {
                    inTable = false;
                    headerAdded = false;
                    result.append("\n");
                }
                result.append(lines[i]).append("\n");
            }
        }
        
        return result.toString();
    }
    
    private static String createTableSeparator(String headerLine) {
        String[] columns = headerLine.split("\\|");
        StringBuilder separator = new StringBuilder("|");
        
        int columnCount = 0;
        for (int i = 0; i < columns.length; i++) {
            String col = columns[i].trim();
            if (!col.isEmpty() || (i > 0 && i < columns.length - 1)) {
                columnCount++;
            }
        }
        
        if (headerLine.trim().startsWith("|") && headerLine.trim().endsWith("|")) {
            for (int i = 0; i < columnCount; i++) {
                separator.append(" --- |");
            }
        } else {
            for (int i = 0; i < columnCount; i++) {
                separator.append(" --- |");
            }
        }
        
        return separator.toString();
    }
    
    private static String handleTextFormatting(String content) {
        // Handle text formatting
        content = content.replaceAll("\\\\textbf\\{\\}", "");
        
        Pattern textbfPattern = Pattern.compile("\\\\textbf\\{([^}]*)\\}");
        Matcher textbfMatcher = textbfPattern.matcher(content);
        StringBuffer sb = new StringBuffer();
        while (textbfMatcher.find()) {
            String contentInner = textbfMatcher.group(1);
            if (!contentInner.trim().isEmpty()) {
                textbfMatcher.appendReplacement(sb, Matcher.quoteReplacement("**" + contentInner + "**"));
            } else {
                textbfMatcher.appendReplacement(sb, "");
            }
        }
        textbfMatcher.appendTail(sb);
        content = sb.toString();
        
        content = content.replaceAll("\\\\textit\\{([^}]+)\\}", "*$1*");
        content = content.replaceAll("\\\\emph\\{([^}]+)\\}", "*$1*");
        
        // Handle hyperlinks
        content = content.replaceAll("\\\\hyperlink\\{[^}]+\\}\\{([^}]+)\\}", "$1");
        content = content.replaceAll("\\\\pageref\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\href\\{([^}]+)\\}\\{[^}]+\\}", "$1");
        
        return content;
    }
    
    private static String addTableSeparators(String content) {
        // Define table patterns that need separators
        String[][] tablePatterns = {
            {"\\| \\*\\*CM\\*\\* \\| \\*\\*PM\\*\\* \\| \\*\\*CM\\*\\* \\| \\*\\*PM\\*\\* \\| \\*\\*CM\\*\\* \\| \\*\\*PM\\*\\* \\|", "|---|---|---|---|---|---|"},
            {"\\| \\*\\*d%\\*\\* \\| \\*\\*Meteo\\*\\* \\| \\*\\*Clima Freddo\\*\\* \\| \\*\\*Clima Temperato \\{\\*\\*\\*\\} \\| \\*\\*Deserto\\*\\* \\|", "|---|---|---|---|---|"},
            {"\\| \\*\\*d%\\*\\* \\| \\*\\*Weather\\*\\* \\| \\*\\*Cold Climate\\*\\* \\| \\*\\*Temperate Climate \\{\\*\\*\\*\\} \\| \\*\\*Desert\\*\\* \\|", "|---|---|---|---|---|"},
            {"\\| Livello PG \\| Minima \\| Pericolosa \\| Mortale \\|", "|---|---|---|---|"},
            {"\\| Character Level \\| Minimal \\| Dangerous \\| Deadly \\|", "|---|---|---|---|"},
            {"\\| \\*\\*Zampe Creatura\\*\\* \\| \\*\\*CdC\\*\\* \\|", "|---|---|"},
            {"\\| \\*\\*Creature Legs\\*\\* \\| \\*\\*CdC\\*\\* \\|", "|---|---|"},
            {"\\| \\*\\*Livello\\*\\* \\| \\*\\*PX\\*\\* \\| \\*\\*Livello\\*\\* \\| \\*\\*PX\\*\\* \\|", "|---|---|---|---|"},
            {"\\| \\*\\*Level\\*\\* \\| \\*\\*XP\\*\\* \\| \\*\\*Level\\*\\* \\| \\*\\*XP\\*\\* \\|", "|---|---|---|---|"},
            {"\\| \\*\\*4d6\\*\\* \\| \\*\\*Gemme\\*\\* \\| \\*\\*4d6\\*\\* \\| \\*\\*Gemme\\*\\* \\|", "|---|---|---|---|"},
            {"\\| \\*\\*4d6\\*\\* \\| \\*\\*Gems\\*\\* \\| \\*\\*4d6\\*\\* \\| \\*\\*Gems\\*\\* \\|", "|---|---|---|---|"},
            {"\\| \\*\\*4d6\\*\\* \\| \\*\\*Bonus magico\\*\\* \\|", "|---|---|"},
            {"\\| \\*\\*4d6\\*\\* \\| \\*\\*Magic bonus\\*\\* \\|", "|---|---|"}
        };
        
        // Apply table separators
        for (String[] pattern : tablePatterns) {
            content = content.replaceAll(pattern[0], pattern[0].replaceAll("\\\\\\|", "|").replaceAll("\\\\\\*", "*") + "\n" + pattern[1]);
        }
        
        // Add separators for magic item tables
        String[] magicItemHeaders = {
            "\\| \\*\\*1d100\\*\\* \\| \\*\\*Capacità Speciale Armature/Scudi Tipo 1\\*\\* \\|",
            "\\| \\*\\*1d100\\*\\* \\| \\*\\*Special Ability Armor/Shields Type 1\\*\\* \\|",
            "\\| \\*\\*1d100\\*\\* \\| \\*\\*Bacchetta\\*\\* \\|",
            "\\| \\*\\*1d100\\*\\* \\| \\*\\*Wand\\*\\* \\|",
            "\\| \\*\\*3d6\\*\\* \\| \\*\\*Bastone\\*\\* \\|",
            "\\| \\*\\*3d6\\*\\* \\| \\*\\*Staff\\*\\* \\|",
            "\\| \\*\\*1d100\\*\\* \\| \\*\\*Anelli Tipo 1\\*\\* \\|",
            "\\| \\*\\*1d100\\*\\* \\| \\*\\*Rings Type 1\\*\\* \\|",
            "\\| \\*\\*d100\\*\\* \\| \\*\\*Effetto\\*\\* \\|",
            "\\| \\*\\*d100\\*\\* \\| \\*\\*Effect\\*\\* \\|",
            "\\| \\*\\*3d6\\*\\* \\| \\*\\*Effetto\\*\\* \\|",
            "\\| \\*\\*3d6\\*\\* \\| \\*\\*Effect\\*\\* \\|"
        };
        
        for (String header : magicItemHeaders) {
            content = content.replaceAll(header, header.replaceAll("\\\\\\|", "|").replaceAll("\\\\\\*", "*") + "\n|---|---|");
        }
        
        // Fix syllable tables
        content = content.replaceAll("(\\| \\*\\*3d6\\*\\* \\| \\*\\*Sillaba\\*\\* \\| \\*\\*3d6\\*\\* \\| \\*\\*Sillaba\\*\\* \\|)", "$1\n|---|---|---|---|");
        content = content.replaceAll("(\\| \\*\\*3d6\\*\\* \\| \\*\\*Syllable\\*\\* \\| \\*\\*3d6\\*\\* \\| \\*\\*Syllable\\*\\* \\|)", "$1\n|---|---|---|---|");
        content = content.replaceAll("(\\| \\*\\*2d6\\*\\* \\| \\*\\*Sillaba\\*\\* \\| \\*\\*2d6\\*\\* \\| \\*\\*Sillaba\\*\\* \\|)", "$1\n|---|---|---|---|");
        content = content.replaceAll("(\\| \\*\\*2d6\\*\\* \\| \\*\\*Syllable\\*\\* \\| \\*\\*2d6\\*\\* \\| \\*\\*Syllable\\*\\* \\|)", "$1\n|---|---|---|---|");
        
        // Fix name generation tables
        content = content.replaceAll("(\\| \\*\\*2d10\\*\\* \\| \\*\\*Prefisso\\*\\* \\| \\*\\*2d10\\*\\* \\| \\*\\*Prefisso\\*\\* \\| \\*\\*2d10\\*\\* \\| \\*\\*Prefisso\\*\\* \\|)", "$1\n|---|---|---|---|---|---|");
        content = content.replaceAll("(\\| \\*\\*2d10\\*\\* \\| \\*\\*Prefix\\*\\* \\| \\*\\*2d10\\*\\* \\| \\*\\*Prefix\\*\\* \\| \\*\\*2d10\\*\\* \\| \\*\\*Prefix\\*\\* \\|)", "$1\n|---|---|---|---|---|---|");
        content = content.replaceAll("(\\| \\*\\*2d12\\*\\* \\| \\*\\*Iniziale\\*\\* \\| \\*\\*2d12\\*\\* \\| \\*\\*Finale\\*\\* \\|)", "$1\n|---|---|---|---|");
        content = content.replaceAll("(\\| \\*\\*2d12\\*\\* \\| \\*\\*Initial\\*\\* \\| \\*\\*2d12\\*\\* \\| \\*\\*Final\\*\\* \\|)", "$1\n|---|---|---|---|");
        
        return content;
    }
    
    private static String handleSpecialTables(String content) {
        // Handle the magic failure table that has specific formatting
        content = content.replaceAll(
            "\\| 1 \\| Per 1 giorno non sei più in grado di canalizzare energie magiche\\. Non puoi lanciare incantesimi se non facendo un successo magico critico nella Prova di Magia \\|",
            "|3d6|Effetto|\n|---|---|\n| 1 | Per 1 giorno non sei più in grado di canalizzare energie magiche. Non puoi lanciare incantesimi se non facendo un successo magico critico nella Prova di Magia |"
        );
        
        content = content.replaceAll(
            "\\| 1 \\| For 1 day you are no longer able to channel magical energies\\. You cannot cast spells unless making a magic critical success in the Magic Check \\|",
            "|3d6|Effect|\n|---|---|\n| 1 | For 1 day you are no longer able to channel magical energies. You cannot cast spells unless making a magic critical success in the Magic Check |"
        );
        
        return content;
    }
    
    private static String finalCleanup(String content) {
        // Clean up
        content = content.replaceAll("\\*\\*([^*]+):\\*\\*:", "**$1**:");
        content = content.replaceAll("(?m)^\\s*\\}\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[noitemsep.*\\]\\s*$", "");
        
        // Remove standalone braces and percentages
        content = content.replaceAll("(?m)^\\s*\\{\\s*\\}\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\{\\s*\\*\\*[^}]*\\*\\*\\s*\\}\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\{\\s*[^}]*\\}\\s*$", "");
        content = content.replaceAll("(?m)^\\s*%%\\s*$", "");
        content = content.replaceAll("(?m)^\\s*%[^\\n]*$", "");
        content = content.replaceAll("(?m)^\\s*>\\s*$", "");
        
        // Clean up leftover textbf artifacts and environment remnants
        content = content.replaceAll("\\\\textbf(?:\\s|$)", "");
        content = content.replaceAll("\\*\\*\\s*\\*\\*", "");
        content = content.replaceAll("\\*\\*\\*\\*", "");
        content = content.replaceAll("\\\\end\\{narratore\\}", "");
        content = content.replaceAll("\\\\begin\\{narratore\\}", "");
        content = content.replaceAll("\\\\end\\{enfasi\\}", "");
        content = content.replaceAll("\\\\begin\\{enfasi\\}", "");
        
        // Remove leftover braces
        content = content.replaceAll("(?m)^\\s*\\{\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\}\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\}\\}\\s*$", "");
        content = content.replaceAll("\\}$", "");
        content = content.replaceAll("(?<=\\))\\}\\s*$", "");
        content = content.replaceAll("\\}\\}", "");
        
        // Handle quotes - convert specific quotes to blockquotes
        content = content.replaceAll("Tutto ciò che non viene donato va perduto\\. \\(Dominique Lapierre\\)", "> Tutto ciò che non viene donato va perduto. (Dominique Lapierre)");
        content = content.replaceAll("E' un diritto naturale saziarsi l'anima con la vendetta\\. \\(Attila\\)", "> E' un diritto naturale saziarsi l'anima con la vendetta. (Attila)");
        content = content.replaceAll("Est Sularus Oth Mithas", "> Est Sularus Oth Mithas");
        content = content.replaceAll("Dedicato all'unica Donna mai amata, colei che ogni giorno mi accompagna nei sogni", "> Dedicato all'unica Donna mai amata, colei che ogni giorno mi accompagna nei sogni");
        content = content.replaceAll("Mai rinunciare ai tuoi desideri, persevera fino a renderli reali\\.", "> Mai rinunciare ai tuoi desideri, persevera fino a renderli reali.");
        
        // Clean up multiple consecutive page breaks
        content = content.replaceAll("(---\\s*\\n\\s*){2,}", "---\n\n");
        
        // Remove table separators that appear in the middle of tables
        content = content.replaceAll("(?m)^\\s*\\|\\s*---\\s*\\|.*\\n(?=\\s*\\|\\s*[0-9]+)", "");
        
        // Final hyperlink cleanup
        content = content.replaceAll("\\\\hypertarget\\{[^}]*\\}\\{([^}]*)\\}", "$1");
        content = content.replaceAll("\\*\\*\\\\hyperlink\\{([^}]*)\\*\\*\\}", "$1");
        content = content.replaceAll("\\\\hyperlink\\{tagliaedimensioni\\}", "size");
        
        // Remove enumerate environments
        content = content.replaceAll("\\\\begin\\{enumerate\\}\\[leftmargin=\\*\\]", "");
        content = content.replaceAll("\\\\end\\{enumerate\\}", "");
        
        return content;
    }
}
