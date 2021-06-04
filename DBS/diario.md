04/06/2021

per qualche giorno.. o piu' non credo che si saranno modifiche significative. In primis perche' il sistema ha raggiunto una certa stabilita', secondo perche' sono nella fase ain't broken don't fix.
Ovvero metti le mani solo se serve. La prossima fase e' giocare, giocare e verificare e affinare il tutto.
Confido che qualcuno (e non sono pochi..) che hanno scaricato il manuale fornisca anche qualche feedback :)
In ogni caso da appassionato di gdr la soddisfazione e' anche creare qualcosa (e questo e' almeno il mio 5 gdr..), se poi viene anche giocato fuori dalla cerchia del gruppo.. meglio!

03/06/2021

ieri sero ho mandato in stampa la versione 1.1.0. Come ho gia' avuto modo di scrivere e' la versione definitiva su cui effettuare il gioco. La fase di playtesting non terminera' mai dato il mio modo di giocare e "sviluppare" ma questa versione e' un punto fermo.
Per vostra curiosita' la stampa in bianco e nero su Lulu del manuale di DBS (526 pagine) costa circa 18€, una cifra molto abbordabile considerando che ci sono spessisimo sconti/coupon da applicare.
Posso anche fornire il link per comprare una copia!

02/06/2021

sistemare le actions di github e' stato un delirio!
utilita'? che una modifica al "sorgente", al latex direttamente fatto in github, fa produrre il pdf del manuale e questo evita a chi non ha un ambiente latex installato di poter modificare il testo ed ottenere lo stesso il pdf risultante.
Adesso sono in piena bolla, non so piu' cosa toccare e ho paura di fare danni. Il manuale ha una certa stabilita', qualsiasi cambiamento va valutato attentamente.
A parte correnzioni di lingua che dopo 3 riletture sono sicuro ci siano ancora (sic!) devo solo testare approfonditamente.

01/06/2021

delirio! la mia poca conoscenza di git mi ha fatto dannare!
ho voluto sistemare il repository dividendo per cartella TUS e DBS, per quanto si facile a livello di file system su git e' roba diversa...

31/05/2021

riletto tutto, a parte il capitolo sui piani.
conto entro il 4 giugno di rilasciare la 1.1.0. Questa versione che andra' anche in stampa si puo' definire il punto di partenza per la fase definitiva di collaudo e play testing.
Il sistema e' molto maturato e reso piu' omogeneo, sono stati tolte e smussate numerosissime imprecisioni rendendo il sistema piu' coerente.
Per come e' nato e sviluppato ci saranno sempre costantemente piccoli cambiamenti e migliorie, non mi piace un gioco troppo statico, ma confermo che eventuali altri cambiamenti dovranno riguardare una versione diversa per non obbligare i giocatori a prendere piu' versioni dello stesso manuale.
Un approccio utile sarebbe avere un changelog manutenuto da un appassionato che sappia "tradurre" i commit in differenze per produrre un documento leggibile e funzionale.

29/05/2021

la rilettura procede bene. nella sezione trappole, veleni e movimento non ho trovato grossi errori, qualche chiarimento da fare o riferimenti alla distanza in mischia/media...
Ho volutamente saltato la lettura di avventure in xxx, Sto seriamente pensando se rimuoverle o ridurle. Non e' una questione di pagine, ma di coerenza con uno stile osr o aderenza alla ogl.
Vorrei ridurre il piu' possibile il manuale e poche regole essenziali e chiare. Le pagine sono 526, l'inserimento delle illustrazioni e' stato fatto con accuratezza.. allungando solo di 4 pagine l tutto. Direi accettabile.
Per la parte di masterizzazione ammetto che il ritorno ai vecchi px mi attira ma oggettivamente anche un sistema che lavora a pochi punti esperienza e STIMOLA una distribuzione dei punti diversa tra personaggi mi va bene. Francamente il passare tutti insieme il livello, appiattire il livello di gioco, tutti bravi uguali.. non mi piace. Ogni giocatore e' un universo a parte e merita punti esperienza in maniera diversa dagli altri.
Terminata la lettura molto probabilmente aspettero' 2 settimane, controllero qualche pagina e pubblichero' la 1.1.0 e mandero' in stampa.
Questa versione a livello tecnico la valuto almeno un 90-95% definitiva.
Il grosso del lavoro sara' poi da fare sul settings.


26/05/2021

rileggendo l'equipaggiamento ho trovato una nota sulla lista pugno nudo, fatto il collegamento alla lista d'armi e qui mi sono accorto che i danni e punteggi necessari in lista non tornavano. Non solo non tornavano ma erano completamente sbagliati in pratica c'era il livello al posto del punteggio di CA!. Sistemato...
Ho anche voluto indicare, prima mancava, il modificatore alla magia per le armature in pelle di drago (materiali speciali). Ho deciso che le armature di drago non danno penalita' alle prove di CM... Ardito ma mi piace, oltretutto e' una tipologia di materiale non solo rara ma che ha una storia (del drago..) dietro.

Non leggero' gli incantesimi ne i mostri, quelli devono essere testati sul campo (anche se non vedo grossi motivi di preoccupazione).

Terminato il giro di lettura sara' interessante effettuare un altro giro pesante di playtesting.


25/05/2021

Ho avviato questo diario di sviluppo solo oggi, ma e' molto che ci pensavo. Scrivero' commenti e pensieri relaviti allo sviluppo del sistema (DBS principalmente).

Sono piuttosto contento della rilettura, sono riuscito a trovare numerose imprecisioni e a modificare, rendendo piu' lineare, diveri punti.
La versione precedente, la 109, e' comunque buona e valida, ma come sempre l'ultima e' sempre meglio.
Molto probabilmente dopo il termine di questa rilettura procedero' ad un altra stampa. E' assurdo quanti errori e correzioni si fanno ogni volta che si rilegge. 
Ovvio che ogni volta rileggi con l'esperienza maturata ma mi rendo sempre piu' conto che un "professionista" o anche solo un esterno potrebbe trovare molte piu' imprecisioni considerando che e' estraneo al sistema.
Tra i prossimi punti da fare c'e' la parte dei draghi e Yeru. Mi piacerebbe investire tempo e riuscire a creare qualcosa di significativo anche se il tempo a disposizione e' poco.
Yeru puo' avere ottime potenzialita'.
Sono molto piu' accorto nei commit, adesso compilo in "casa" e committo solo dopo un certo numero di modifiche oppure modifiche significative (o detta diversamente errori grossolani!).
Ho aggiunto google analytics al progetto di github per avere una idea se sto lavorando solo per me stesso (ed il mio gruppo).. o per altri. Non che abbia chissa' quale velleita' pero' mi fa piacere vedere che il repository viene clonato!
Spero che sia letto e che riceva feedback.
Mi rendo conto che il sistema puo' essere visto con un continuo ed eccessivo cambiamento, ma ripeto, se volete giocare usate l'ultima versione pubblicata, pur con tutti i limiti che puo' avere e' comunque "stabile", poi.. quando volete passate alla versione dopo ma mi raccomando leggete il changelog per avere una idea di cosa e' cambiato, spesso sono cose sottili.
L'ideale sarebbe che il Narratore seguisse lo sviluppo, e che ai giocatori venisse presentata solo la versione con cui si vuole giocare.
Personalmente reputo la 1.1.0 un ottima versione anche se in fase di sviluppo. La rilettura e' ormai completa.
