# .latexmkrc - Configurazione per latexmk con XeLaTeX
# Posiziona questo file nella directory di lavoro o nella home directory

# Usa XeLaTeX come motore principale
$pdf_mode = 5; # 5 = xelatex

# Comando XeLaTeX personalizzato con synctex
$xelatex = 'xelatex -synctex=1 -interaction=nonstopmode -file-line-error %O %S';

# Configurazione per la bibliografia
$bibtex_use = 2; # Usa bibtex quando necessario
$biber = 'biber %O --bblencoding=utf8 -u -U --output_safechars %B';

# Numero massimo di passaggi
$max_repeat = 5;

# Pulisce i file ausiliari alla fine
$cleanup_mode = 1;

# File da mantenere dopo la pulizia
$clean_ext = 'auxlock figlist makefile run.xml fls_latexmk bbl bcf run synctex.gz';

# File da rimuovere durante la pulizia completa
$clean_full_ext = 'auxlock figlist makefile run.xml fls_latexmk bbl bcf run synctex.gz nav snm vrb';

# Configurazione per il viewer PDF (opzionale)
# $pdf_previewer = 'evince %O %S';

# Attiva il monitoraggio continuo (per -pvc)
$preview_continuous_mode = 1;

# Genera sempre il file .fls per il tracking delle dipendenze
$recorder = 1;

# Configurazione per sottodirectory
$do_cd = 1; # Cambia directory nel file di input

# Encoding predefinito
$ENV{'LANG'} = 'en_US.UTF-8';
$ENV{'LC_ALL'} = 'en_US.UTF-8';

# Gestione errori migliorata
$force_mode = 0; # Non forzare la compilazione in caso di errori

# Timeout per le compilazioni lunghe (in secondi)
$timeout = 600;

# Configurazione per file di indice (se utilizzati)
add_cus_dep('glo', 'gls', 0, 'run_makeglossaries');
add_cus_dep('acn', 'acr', 0, 'run_makeglossaries');
add_cus_dep('alg', 'glg', 0, 'run_makeglossaries');

sub run_makeglossaries {
    my ($base_name, $path) = fileparse($_[0]);
    pushd $path;
    my $return = system "makeglossaries", $base_name;
    popd;
    return $return;
}

# Configurazione per nomenclature (se utilizzata)
add_cus_dep('nlo', 'nls', 0, 'makenlo2nls');
sub makenlo2nls {
    system("makeindex $_[0].nlo -s nomencl.ist -o $_[0].nls -t $_[0].nlg");
}

# Gestione delle immagini eps (conversione automatica)
add_cus_dep('eps', 'pdf', 0, 'eps2pdf');
sub eps2pdf {
    system("epstopdf $_[0].eps");
}

# Configurazione avanzata per la gestione delle dipendenze
$hash_calc_ignore_pattern{'eps'} = '^%%CreationDate: ';
$hash_calc_ignore_pattern{'pdf'} = '^/(CreationDate|ModDate|ID) ';

# Stampa informazioni di debug (commentare per produzione)
# $silent = 0;
# $verbose = 1;