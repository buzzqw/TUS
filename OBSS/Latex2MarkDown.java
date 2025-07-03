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
                Files.writeString(Paths.get(outputFile), converted);
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
        
        // Handle page breaks - convert to markdown page separators with proper spacing
        content = content.replaceAll("\\\\pagebreak(?:\\s*~)?", "\n\n---\n\n");
        content = content.replaceAll("\\\\newpage(?:\\s*~)?", "\n\n---\n\n");
        
        // Ensure page breaks always have proper spacing and are never attached to text
        content = content.replaceAll("([^\\n\\s])\\s*\\n\\s*---\\s*\\n", "$1\n\n---\n\n");
        content = content.replaceAll("\\n\\s*---\\s*\\n([^\\n\\s])", "\n\n---\n\n$1");
        // Handle cases where --- appears at end of line with text
        content = content.replaceAll("([^\\n])---", "$1\n\n---");
        content = content.replaceAll("---([^\\n])", "---\n\n$1");
        
        // Remove comments AFTER multicolumn processing
        content = content.replaceAll("(?m)^\\s*%.*$", "");
        
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
        
        // Remove rule commands (horizontal lines)
        content = content.replaceAll("\\\\rule\\{[^}]*\\}\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\noindent\\\\rule\\{[^}]*\\}\\{[^}]*\\}", "");
        
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
        
        // Handle section headings including titlespacing combinations
        content = content.replaceAll("\\\\titlespacing\\*\\{\\\\subsubsection\\}\\{[^}]*\\}\\{[^}]*\\}\\{[^}]*\\}\\s*\\\\subsubsection\\*\\{([^}]*)\\}(?:\\\\index(?:\\[[^\\]]*\\])?\\{[^}]+\\})*(?:\\s*\\\\emph\\{[^}]*\\})*(?:\\s*\\\\textbf\\{[^}]*\\})*(?:\\\\index(?:\\[[^\\]]*\\])?\\{[^}]+\\})*(?:\\\\label\\{[^}]+\\})*", "### $1");
        content = content.replaceAll("\\\\titlespacing\\*\\{\\\\subsection\\}\\{[^}]*\\}\\{[^}]*\\}\\{[^}]*\\}\\s*\\\\subsection\\*\\{([^}]*)\\}", "## $1");
        content = content.replaceAll("\\\\titlespacing\\*\\{\\\\section\\}\\{[^}]*\\}\\{[^}]*\\}\\{[^}]*\\}\\s*\\\\section\\*\\{([^}]*)\\}", "# $1");
        
        content = content.replaceAll("\\\\section\\*?\\{([^}]*)\\}", "# $1");
        content = content.replaceAll("\\\\subsection\\*?\\{([^}]*)\\}", "## $1");
        content = content.replaceAll("\\\\subsubsection\\*?\\{([^}]*)\\}", "### $1");
        
        // Remove various LaTeX commands and artifacts
        content = content.replaceAll("\\\\(?:vfill|smallskip|medskip|bigskip|noindent)", "");
        content = content.replaceAll("\\\\titlespacing\\*\\{[^}]+\\}\\{[^}]*\\}\\{[^}]*\\}\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\stepcounter\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\newcounter\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\setlength\\{[^}]+\\}\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\setlength\\{\\\\itemsep\\}\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\columnbreak", "");
        content = content.replaceAll("\\\\small\\{?", "");
        content = content.replaceAll("\\\\normalsize", "");
        content = content.replaceAll("\\\\arraybackslash", "");
        content = content.replaceAll("\\\\centering", "");
        content = content.replaceAll("\\\\st\\{[^}]*\\}", "\\\\st");
        content = content.replaceAll("\\\\st\\{([^}]*)\\}", "~~$1~~");
        content = content.replaceAll("\\\\thispagestyle\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\pagenumbering\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\setcounter\\{[^}]+\\}\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\cleardoublepage", "");
        content = content.replaceAll("\\\\fontsize\\{[^}]+\\}\\{[^}]+\\}\\\\selectfont", "");
        content = content.replaceAll("\\\\def\\s*\\\\versione\\s*\\{[^}]+\\}", "");
        content = content.replaceAll("\\\\versione", "1.0.0");
        content = content.replaceAll("\\\\today", "");
        content = content.replaceAll("\\\\vspace\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\vspace", "");
        content = content.replaceAll("\\\\tableofcontents\\{\\}", "");
        
        // Handle resizebox - remove it but keep the content
        content = content.replaceAll("\\\\resizebox\\{[^}]*\\}\\{[^}]*\\}\\{([^}]*)\\}", "$1");
        
        // Remove dimension specifications and coordinates
        content = content.replaceAll("\\([0-9.]+cm,[0-9.]+cm\\)", "");
        content = content.replaceAll("\\{[0-9.]+(?:cm|textwidth|linewidth|hsize)\\}", "");
        content = content.replaceAll("\\{[0-9.]+\\}", "");
        content = content.replaceAll("\\{[0-9.]+cm\\}\\{[0-9.]+cm\\}\\{", "");
        
        // Remove table column specifications
        content = content.replaceAll("\\{[llrcX|>\\\\{}\\-<.=0-9hsize]+\\}", "");
        content = content.replaceAll("\\{[lrc]+\\}", "");
        content = content.replaceAll("\\{\\\\linewidth\\}\\{[^}]+\\}", "");
        
        // Remove mdframed parameters
        content = content.replaceAll("\\[roundcorner=[^\\]]*\\]", "");
        
        // ============================================
        // UPDATED SECTION: Handle NEW custom environments from the updated preamble
        // ============================================
        
        // Handle 'narratore' environment with optional parameter
        Pattern narratorePattern = Pattern.compile(
            "\\\\begin\\{narratore\\}(?:\\[([^\\]]+)\\])?([\\s\\S]*?)\\\\end\\{narratore\\}",
            Pattern.DOTALL
        );
        Matcher narratoreMatcher = narratorePattern.matcher(content);
        StringBuffer sb_narratore = new StringBuffer();
        while (narratoreMatcher.find()) {
            String title = narratoreMatcher.group(1);
            String narratoreContent = narratoreMatcher.group(2);
            
            // Clean the content
            narratoreContent = cleanBoxContent(narratoreContent);
            
            // Use custom title if provided, otherwise use default
            String finalTitle = (title != null && !title.trim().isEmpty()) ? title : "Narratore";
            
            narratoreMatcher.appendReplacement(sb_narratore, 
                Matcher.quoteReplacement("\n>>> **" + finalTitle + "**: " + narratoreContent + "\n"));
        }
        narratoreMatcher.appendTail(sb_narratore);
        content = sb_narratore.toString();
        
        // Handle 'giocatore' environment with optional parameter
        Pattern giocatorePattern = Pattern.compile(
            "\\\\begin\\{giocatore\\}(?:\\[([^\\]]+)\\])?([\\s\\S]*?)\\\\end\\{giocatore\\}",
            Pattern.DOTALL
        );
        Matcher giocatoreMatcher = giocatorePattern.matcher(content);
        StringBuffer sb_giocatore = new StringBuffer();
        while (giocatoreMatcher.find()) {
            String title = giocatoreMatcher.group(1);
            String giocatoreContent = giocatoreMatcher.group(2);
            
            // Clean the content
            giocatoreContent = cleanBoxContent(giocatoreContent);
            
            // Use custom title if provided, otherwise use default
            String finalTitle = (title != null && !title.trim().isEmpty()) ? title : "Giocatore";
            
            giocatoreMatcher.appendReplacement(sb_giocatore, 
                Matcher.quoteReplacement("\n>> **" + finalTitle + "**: " + giocatoreContent + "\n"));
        }
        giocatoreMatcher.appendTail(sb_giocatore);
        content = sb_giocatore.toString();
        
        // Handle 'enfasi' environment (no parameters in new version)
        Pattern enfasiPattern = Pattern.compile(
            "\\\\begin\\{enfasi\\}([\\s\\S]*?)\\\\end\\{enfasi\\}",
            Pattern.DOTALL
        );
        Matcher enfasiMatcher = enfasiPattern.matcher(content);
        StringBuffer sb_enfasi = new StringBuffer();
        while (enfasiMatcher.find()) {
            String enfasiContent = enfasiMatcher.group(1);
            
            // Clean the content
            enfasiContent = cleanBoxContent(enfasiContent);
            
            enfasiMatcher.appendReplacement(sb_enfasi, 
                Matcher.quoteReplacement("\n> " + enfasiContent + "\n"));
        }
        enfasiMatcher.appendTail(sb_enfasi);
        content = sb_enfasi.toString();
        
        // Handle nested tcolorbox with title parameter and complex content (including nested boxes)
        Pattern nestedTcolorboxTitleComplexPattern = Pattern.compile(
            "\\\\begin\\{changemargin\\}\\{[^}]*\\}\\{[^}]*\\}\\\\begin\\{tcolorbox\\}\\[title\\s*=\\s*([^\\]]+)\\]([\\s\\S]*?)\\\\end\\{tcolorbox\\}\\\\end\\{changemargin\\}",
            Pattern.DOTALL
        );
        Matcher nestedTcolorboxTitleComplexMatcher = nestedTcolorboxTitleComplexPattern.matcher(content);
        StringBuffer sb_tcolorbox_complex = new StringBuffer();
        while (nestedTcolorboxTitleComplexMatcher.find()) {
            String title = nestedTcolorboxTitleComplexMatcher.group(1).trim();
            String boxContent = nestedTcolorboxTitleComplexMatcher.group(2);
            
            // Clean up the content
            boxContent = cleanBoxContent(boxContent);
            
            nestedTcolorboxTitleComplexMatcher.appendReplacement(sb_tcolorbox_complex, 
                Matcher.quoteReplacement("\n>> **" + title + "**: " + boxContent + "\n"));
        }
        nestedTcolorboxTitleComplexMatcher.appendTail(sb_tcolorbox_complex);
        content = sb_tcolorbox_complex.toString();
        
        // ============================================
        // Handle remaining cases (standalone boxes and simple cases)
        // ============================================
        
        // Handle description environment - convert to proper list format
        // Remove description environment tags and their parameters
        content = content.replaceAll("\\\\begin\\{description\\}(?:\\[[^\\]]*\\])?", "");
        content = content.replaceAll("\\\\end\\{description\\}", "");
        
        // Remove other environment commands and their parameters
        content = content.replaceAll("\\\\begin\\{(?:multicols|flushleft|flushright|changemargin|itemize|mdframed|textblock\\*)(?:[^}]*)?\\}", "");
        content = content.replaceAll("\\\\end\\{(?:multicols|flushleft|flushright|changemargin|itemize|mdframed|textblock\\*)\\}", "");
        
        // Handle remaining tcolorbox cases - only simple standalone cases not already processed
        // Handle standalone tcolorbox with title in parameters (not nested in changemargin)
        Pattern standaloneTcolorboxTitleParamPattern = Pattern.compile(
            "\\\\begin\\{tcolorbox\\}\\[title\\s*=\\s*([^\\]]+)\\]([\\s\\S]*?)\\\\end\\{tcolorbox\\}",
            Pattern.DOTALL
        );
        Matcher standaloneTcolorboxTitleParamMatcher = standaloneTcolorboxTitleParamPattern.matcher(content);
        StringBuffer sb4a = new StringBuffer();
        while (standaloneTcolorboxTitleParamMatcher.find()) {
            String title = standaloneTcolorboxTitleParamMatcher.group(1).trim();
            String boxContent = standaloneTcolorboxTitleParamMatcher.group(2);
            boxContent = cleanBoxContent(boxContent);
            standaloneTcolorboxTitleParamMatcher.appendReplacement(sb4a, Matcher.quoteReplacement("\n>> **" + title + "**: " + boxContent + "\n"));
        }
        standaloneTcolorboxTitleParamMatcher.appendTail(sb4a);
        content = sb4a.toString();
        
        // Handle simple standalone tcolorbox (simple blockquote)
        Pattern tcolorboxPattern = Pattern.compile(
            "\\\\begin\\{tcolorbox\\}(?:\\[[^\\]]*\\])?(?:\\{([^}]*)\\})?([\\s\\S]*?)\\\\end\\{tcolorbox\\}",
            Pattern.DOTALL
        );
        Matcher tcolorboxMatcher = tcolorboxPattern.matcher(content);
        StringBuffer sb4 = new StringBuffer();
        while (tcolorboxMatcher.find()) {
            String title = tcolorboxMatcher.group(1);
            String boxContent = tcolorboxMatcher.group(2);
            boxContent = cleanBoxContent(boxContent);
            if (title != null && !title.isEmpty()) {
                tcolorboxMatcher.appendReplacement(sb4, Matcher.quoteReplacement("\n>> **" + title + "**: " + boxContent + "\n"));
            } else {
                // Simple quote without title
                tcolorboxMatcher.appendReplacement(sb4, Matcher.quoteReplacement("\n>> " + boxContent + "\n"));
            }
        }
        tcolorboxMatcher.appendTail(sb4);
        content = sb4.toString();
        
        // Remove TikZ and complex graphics commands - including full tikzpicture environments
        content = content.replaceAll("(?s)\\\\begin\\{tikzpicture\\}.*?\\\\end\\{tikzpicture\\}", "");
        content = content.replaceAll("\\\\tikz\\[[^\\]]*\\][^;]*;", "");
        content = content.replaceAll("\\\\node\\[[^\\]]*\\][^;]*;", "");
        
        // Handle custom commands from the new preamble
        content = content.replaceAll("\\\\OBSSseparator", "\n\n---\n\n");
        content = content.replaceAll("\\\\FatePoint", "•");
        content = content.replaceAll("\\\\FatePoints\\{([0-9]+)\\}", generateFatePoints("$1"));
        
        // Handle color commands for tables
        content = content.replaceAll("\\\\(?:obssgrey|obsspurple|obssblue|obssgreen|obsscoral)", "");
        content = content.replaceAll("\\\\obsssetcolor\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\arrayrulecolor\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\setlength\\{\\\\arrayrulewidth\\}\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\rowcolors\\{[^}]*\\}\\{[^}]*\\}\\{[^}]*\\}", "");
        
        // Handle font size commands
        content = content.replaceAll("\\\\(?:Huge|LARGE|Large|large)\\s*", "");
        content = content.replaceAll("\\\\(?:huge|LARGE|Large|large)\\{([^}]*)\\}", "$1");
        
        // Handle color commands
        content = content.replaceAll("\\\\color\\{[^}]*\\}", "");
        content = content.replaceAll("\\\\textcolor\\{[^}]*\\}\\{([^}]*)\\}", "$1");
        
        // Handle lists - process items with textbf first (description list format)
        Pattern itemPattern = Pattern.compile("\\\\item\\s*\\[\\s*\\\\textbf\\{([^}]*)\\}\\s*\\]");
        Matcher itemMatcher = itemPattern.matcher(content);
        StringBuffer sb5 = new StringBuffer();
        while (itemMatcher.find()) {
            String label = itemMatcher.group(1);
            // Remove trailing colon if present
            if (label.endsWith(":")) {
                label = label.substring(0, label.length() - 1);
            }
            itemMatcher.appendReplacement(sb5, Matcher.quoteReplacement("- **" + label + "**:"));
        }
        itemMatcher.appendTail(sb5);
        content = sb5.toString();
        
        // Handle remaining items and list parameters
        content = content.replaceAll("\\\\item\\s*\\[\\s*\\*\\*([^*]+)\\*\\*:?\\s*\\]", "- **$1**:");
        content = content.replaceAll("(?m)^\\s*\\\\item\\s*", "- ");
        content = content.replaceAll("(?m)^\\s*\\[leftmargin[^\\]]*\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[noitemsep[^\\]]*\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[topsep[^\\]]*\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[parsep[^\\]]*\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[partopsep[^\\]]*\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[labelwidth[^\\]]*\\]\\s*$", "");
        
        // Handle hyperlinks - extract only the display text (second part)
        content = content.replaceAll("\\\\hyperlink\\{[^}]+\\}\\{([^}]+)\\}", "$1");
        content = content.replaceAll("\\\\pageref\\{[^}]+\\}", "");
        
        // Handle href links - extract only the URL (first part)
        content = content.replaceAll("\\\\href\\{([^}]+)\\}\\{[^}]+\\}", "$1");
        
        // Remove excessive indentation from list items (tabs and multiple spaces)
        content = content.replaceAll("(?m)^\\s*\\t+\\s*-", "-");
        content = content.replaceAll("(?m)^\\s{4,}-", "-");
        
        // Handle text formatting - fix textbf with empty or single character content
        content = content.replaceAll("\\\\textbf\\{\\}", "");
        
        Pattern textbfPattern = Pattern.compile("\\\\textbf\\{([^}]*)\\}");
        Matcher textbfMatcher = textbfPattern.matcher(content);
        StringBuffer sb6 = new StringBuffer();
        while (textbfMatcher.find()) {
            String content_inner = textbfMatcher.group(1);
            if (!content_inner.trim().isEmpty()) {
                textbfMatcher.appendReplacement(sb6, Matcher.quoteReplacement("**" + content_inner + "**"));
            } else {
                textbfMatcher.appendReplacement(sb6, "");
            }
        }
        textbfMatcher.appendTail(sb6);
        content = sb6.toString();
        
        content = content.replaceAll("\\\\textit\\{([^}]+)\\}", "*$1*");
        content = content.replaceAll("\\\\emph\\{([^}]+)\\}", "*$1*");
        content = content.replaceAll("\\\\textsc\\{([^}]+)\\}", "$1");
        content = content.replaceAll("\\\\texttt\\{([^}]+)\\}", "`$1`");
        
        // Handle tables - multicolumn already processed at the top
        content = content.replaceAll("\\\\begin\\{(?:tabular\\*?|tabularx|xltabular)(?:[^}]*)?\\}", "");
        content = content.replaceAll("\\\\end\\{(?:tabular\\*?|tabularx|xltabular)\\}", "");
        content = content.replaceAll("\\\\(?:toprule|midrule|bottomrule|hline)", "");
        content = content.replaceAll("\\\\cmidrule(?:\\([^)]*\\))?(?:\\[[^\\]]+\\])?\\{[^}]+\\}", "");
        
        // Remove any remaining \multicolumn and \multirow references that weren't processed
        content = content.replaceAll("\\\\multicolumn\\{[^}]*\\}\\{[^}]*\\}\\{[^}]*\\}", "LEFTOVER_MULTICOLUMN");
        content = content.replaceAll("\\\\multicolumn\\{[^}]*\\}", "LEFTOVER_MULTICOLUMN2");
        content = content.replaceAll("\\\\multirow\\{[^}]*\\}\\*?\\{[^}]*\\}", "LEFTOVER_MULTIROW");
        
        // Convert table separators - handle empty cells at end properly
        content = content.replaceAll("\\s*&\\s*", " | ");
        content = content.replaceAll("&\\s*\\\\\\\\", " |\n");  // Handle & followed by \\ - add newline for table rows
        content = content.replaceAll("\\s*\\\\\\\\\\s*", " |\n");  // Handle \\ at end of table rows - add newline
        
        // FIXED: Handle line breaks (\\) outside of tables - Convert to proper line breaks
        // This needs to be done after table processing to avoid interfering with table rows
        content = content.replaceAll("\\\\\\\\", "\n");
        
        // Convert table separators and create proper markdown tables
        String[] lines = content.split("\n");
        StringBuilder result = new StringBuilder();
        boolean inTable = false;
        boolean headerAdded = false;
        
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i].trim();
            
            // Check if this line looks like a table row, but exclude blockquotes and be more restrictive
            if (line.contains("|") && !line.startsWith(">") && !line.startsWith("###")) {
                // Additional check: make sure it's actually a table and not just text with |
                long pipeCount = line.chars().filter(ch -> ch == '|').count();
                
                // Check for different table patterns - be more inclusive for simple tables
                if ((pipeCount >= 1 && (line.matches(".*\\w+:\\s*\\|.*") || 
                      line.matches(".*\\*[^*]+\\*:\\s*\\|.*"))) ||
                    (pipeCount >= 2 && line.contains("**") && 
                     (line.matches(".*\\*\\*[^*]+\\*\\*\\s*\\|.*\\*\\*[^*]+\\*\\*.*") ||
                      line.matches(".*[0-9]+\\s*\\|.*[0-9]+\\s*\\|.*") ||
                      line.matches(".*\\*\\*[^*]+\\*\\*\\s*\\|.*"))) ||
                    (pipeCount >= 1 && line.matches(".*[A-Za-z0-9].*\\|.*[A-Za-z0-9$±\\-+*].*")) ||
                    // Special case for incomplete table rows that need fixing
                    (line.matches("^[0-9]+\\s+\\|.*") || line.matches("^[0-9]+\\s.*\\|.*")) ||
                    // Handle lines that start with text and contain |
                    (pipeCount >= 1 && line.matches("^[A-Za-z].*\\|.*"))) {
                    
                    if (!inTable) {
                        inTable = true;
                        headerAdded = false;
                        // Add an empty line before table if previous line exists and isn't empty
                        if (result.length() > 0 && !result.toString().endsWith("\n\n")) {
                            result.append("\n");
                        }
                    }
                    
                    // Fix rows that start with number but no | (like "8 | 8 | 0 | 8d6+24 |")
                    if (line.matches("^[0-9]+\\s+.*\\|.*") && !line.startsWith("|")) {
                        line = "| " + line;
                    }
                    // Add table prefix if not already there
                    else if (!line.startsWith("|")) {
                        line = "| " + line;
                    }
                    
                    // Make sure line ends with |
                    if (!line.endsWith("|")) {
                        line = line + " |";
                    }
                    
                    result.append(line).append("\n");
                    
                    // Add separator after first row (header)
                    if (!headerAdded) {
                        String separator = createTableSeparator(line);
                        result.append(separator).append("\n");
                        headerAdded = true;
                    }
                } else {
                    // Not a table row, just regular text that happens to contain |
                    // Remove trailing | from non-table lines
                    if (line.endsWith(" |")) {
                        line = line.substring(0, line.length() - 2).trim();
                    }
                    if (inTable) {
                        inTable = false;
                        headerAdded = false;
                        result.append("\n"); // Add spacing after table
                    }
                    result.append(line).append("\n");
                }
            } else {
                if (inTable && !line.isEmpty() && !line.startsWith("###")) {
                    inTable = false;
                    headerAdded = false;
                    result.append("\n"); // Add spacing after table
                }
                result.append(lines[i]).append("\n");
            }
        }
        content = result.toString();
        
        // Clean up
        content = content.replaceAll("\\*\\*([^*]+):\\*\\*:", "**$1**:");
        content = content.replaceAll("(?m)^\\s*\\}\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[noitemsep.*\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\{\\\\subsubsection\\}\\{[^}]*\\}\\{[^}]*\\}\\{[^}]*\\}\\s*$", "");
        
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
        
        // Remove leftover braces from content and trailing }
        content = content.replaceAll("(?m)^\\s*\\{\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\}\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\}\\}\\s*$", "");
        content = content.replaceAll("\\}$", "");
        content = content.replaceAll("(?<=\\))\\}\\s*$", "");
        content = content.replaceAll("\\}\\}", "");
        
        // Remove description list parameters that may have been left over
        content = content.replaceAll("(?m)^\\s*\\[noitemsep.*?\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[topsep.*?\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[parsep.*?\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[partopsep.*?\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[leftmargin.*?\\]\\s*$", "");
        content = content.replaceAll("(?m)^\\s*\\[labelwidth.*?\\]\\s*$", "");
        
        // Clean up multiple consecutive page breaks and fix table separators in wrong places
        content = content.replaceAll("(---\\s*\\n\\s*){2,}", "---\n\n");
        
        // Remove table separators that appear in the middle of tables
        content = content.replaceAll("(?m)^\\s*\\|\\s*---\\s*\\|.*\\n(?=\\s*\\|\\s*[0-9]+)", "");
        
        // Remove everything after \end{document} or document ending markers
        int documentEnd = content.indexOf("\\end{document}");
        if (documentEnd != -1) {
            content = content.substring(0, documentEnd);
        }
        
        // Remove TotalBox commands and associated content
        content = content.replaceAll("(?s)\\\\TotalBox\\{[^}]+\\}.*?(?=\\\\TotalBox|$)", "");
        content = content.replaceAll("\\\\TotalBox\\{[^}]+\\}", "");
        
        // Remove bibliography commands
        content = content.replaceAll("\\\\printbibliography", "");
        
        // Handle special textpos and tikz overlay commands from cover page
        content = content.replaceAll("(?s)\\\\tikz\\[remember picture,overlay\\].*?;", "");
        content = content.replaceAll("(?s)\\\\begin\\{textblock\\*\\}.*?\\\\end\\{textblock\\*\\}", "");
        
        // Remove font awesome icons
        content = content.replaceAll("\\\\fa[A-Za-z]+", "");
        
        // Remove excessive whitespace
        content = content.replaceAll("\n{3,}", "\n\n");
        content = content.trim();
        
        return content;
    }
    
    private static String createTableSeparator(String headerLine) {
        // Count the number of columns in the header by counting pipes
        String[] columns = headerLine.split("\\|");
        StringBuilder separator = new StringBuilder("|");
        
        // Count actual columns (excluding empty first/last if they exist due to leading/trailing |)
        int columnCount = 0;
        for (int i = 0; i < columns.length; i++) {
            String col = columns[i].trim();
            if (!col.isEmpty() || (i > 0 && i < columns.length - 1)) {
                columnCount++;
            }
        }
        
        // If line starts and ends with |, we need one separator per column between pipes
        if (headerLine.trim().startsWith("|") && headerLine.trim().endsWith("|")) {
            // For "| col1 | col2 | col3 | col4 |" we need "| --- | --- | --- | --- |"
            for (int i = 0; i < columnCount; i++) {
                separator.append(" --- |");
            }
        } else {
            // For lines without leading/trailing pipes
            for (int i = 0; i < columnCount; i++) {
                separator.append(" --- |");
            }
        }
        
        return separator.toString();
    }
    
    // Helper method to generate fate points
    private static String generateFatePoints(String count) {
        try {
            int n = Integer.parseInt(count);
            StringBuilder result = new StringBuilder();
            for (int i = 0; i < n; i++) {
                result.append("• ");
            }
            return result.toString().trim();
        } catch (NumberFormatException e) {
            return "• • •"; // Default to 3 points if parsing fails
        }
    }
    
    // Helper method to clean box content from LaTeX commands
    private static String cleanBoxContent(String content) {
        if (content == null) return "";
        
        // Handle text formatting first (before cleaning spacing)
        content = content.replaceAll("\\\\emph\\{([^}]+)\\}", "*$1*");
        content = content.replaceAll("\\\\textit\\{([^}]+)\\}", "*$1*");
        content = content.replaceAll("\\\\textbf\\{([^}]+)\\}", "**$1**");
        content = content.replaceAll("\\\\textsc\\{([^}]+)\\}", "$1");
        content = content.replaceAll("\\\\texttt\\{([^}]+)\\}", "`$1`");
        
        // Handle color commands
        content = content.replaceAll("\\\\textcolor\\{[^}]*\\}\\{([^}]*)\\}", "$1");
        content = content.replaceAll("\\\\color\\{[^}]*\\}", "");
        
        // Handle FontAwesome icons
        content = content.replaceAll("\\\\fa[A-Za-z]+", "");
        
        // Handle center environment
        content = content.replaceAll("\\\\begin\\{center\\}([\\s\\S]*?)\\\\end\\{center\\}", "$1");
        
        // Remove comments
        content = content.replaceAll("%[^\\n]*", "");
        
        // Handle spacing commands but preserve natural line breaks
        content = content.replaceAll("\\\\(?:smallskip|medskip|bigskip)\\s*", "");
        content = content.replaceAll("\\\\vspace\\{[^}]*\\}\\s*", "");
        content = content.replaceAll("\\\\hspace\\{[^}]*\\}\\s*", "");
        
        // Handle custom OBSS commands
        content = content.replaceAll("\\\\FatePoint", "•");
        content = content.replaceAll("\\\\FatePoints\\{([0-9]+)\\}", generateFatePoints("$1"));
        
        // Remove stray braces that might be left over
        content = content.replaceAll("^\\{", "");  // Remove opening brace at start
        content = content.replaceAll("\\}$", "");  // Remove closing brace at end
        content = content.replaceAll("(?<!\\\\)\\{([^}]*)\\}(?!\\})", "$1");  // Remove simple braces around content
        
        // Clean up whitespace while preserving line structure
        content = content.replaceAll("[ \\t]+", " ");  // Multiple spaces/tabs to single space
        content = content.replaceAll("\\n[ \\t]*\\n", "\n\n");  // Clean empty lines
        content = content.replaceAll("\\n[ \\t]+", "\n");  // Remove spaces after newlines
        content = content.replaceAll("[ \\t]+\\n", "\n");  // Remove spaces before newlines
        
        // Normalize multiple consecutive newlines to double newlines (paragraph breaks)
        content = content.replaceAll("\\n{3,}", "\n\n");
        
        // Trim leading/trailing whitespace but preserve internal structure
        content = content.trim();
        
        return content;
    }
}
