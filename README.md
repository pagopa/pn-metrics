# Pn-metrics

Questo repository contiene script e query di analisi per monitorare il prodotto SEND.

## Mermaid Diagrams – Quick Guide

Questa guida spiega come creare, gestire ed esportare **diagrammi Mermaid** utilizzando **Visual Studio Code (VS Code)** con l'estensione **Mermaid Preview**. Mermaid è un linguaggio di markup per generare diagrammi e grafici direttamente dal testo, utile per documentare modelli dati, workflow e architetture.

### Perché usare Mermaid?

Mermaid offre numerosi vantaggi:
- **Semplicità**: Sintassi testuale facile da scrivere e modificare.
- **Versionamento**: I diagrammi sono file di testo, ideali per il controllo versione Git.
- **Integrazione**: Supporto nativo in piattaforme come GitHub, Confluence e documentazione tecnica.
- **Varietà**: Supporta diagrammi ER, flowchart, Gantt, sequenza e altro.
- **Collaborazione**: Facilita la condivisione e la revisione di diagrammi tecnici.
- **Efficienza**: Creazione rapida senza bisogno di tool grafici complessi.

### Workflow Consigliato

Per mantenere i diagrammi organizzati e aggiornati, segui questo flusso di lavoro:

1. **Scrittura e manutenzione**: Scrivi e mantieni i diagrammi come file Mermaid (`.mmd`) direttamente nel repository. Questo garantisce che i diagrammi siano versionati insieme al codice.
2. **Visualizzazione durante lo sviluppo**: Usa l'estensione Mermaid Preview in VS Code per visualizzare i diagrammi in tempo reale mentre li modifichi.
3. **Esportazione per documentazione**: Quando necessario, esporta le immagini (PNG o SVG) dall'estensione per includerle in documenti esterni o presentazioni.

Questo approccio assicura che i diagrammi rimangano sincronizzati con il codice e siano facilmente accessibili al team.

### Prerequisiti

Prima di iniziare, assicurati di avere tutto il necessario:

- **Visual Studio Code**: Editor di testo gratuito e potente. Scaricalo da [code.visualstudio.com](https://code.visualstudio.com/).
- **Estensione Mermaid Preview**: Per visualizzare e gestire i diagrammi Mermaid:
  - Installazione: Apri VS Code, vai su Extensions (Ctrl+Shift+X), cerca "Mermaid Preview" e installa l'estensione.
  - Link diretto: https://marketplace.visualstudio.com/items?itemName=vstirbu.vscode-mermaid-preview
  - Funzionalità: Permette di aprire una preview interattiva, esportare diagrammi e personalizzare temi.
- **Navigazione nel repository**: Assicurati di essere nella cartella corretta dove salvare i file dei diagrammi (ad esempio, `pn-metrics/data_model/`).

### Convenzioni di Naming

Per mantenere l'ordine e la tracciabilità, segui queste regole di naming per ogni workflow logico che coinvolge entità del modello dati:

- **File Mermaid (`.mmd`)**:
  - Nome: Deve riflettere il workflow o il modulo logico rappresentato.
  - Esempio: `pn_delivery.mmd` per il workflow di consegna delle notifiche.
  - Posizione: Salva nella cartella appropriata, come `data_model/`.

- **Immagine esportata (PNG o SVG)**:
  - Nome: Stesso nome del file `.mmd`, con aggiunta della data di esportazione in formato `DD_MM_YYYY_MM_DD` e versione (`v1`, `v2`, ecc.).
  - Esempio: `pn_delivery_10_03_2026_v1.png`.
  - Scopo: Usata per documentazione esterna dove non è possibile visualizzare i diagrammi interattivi.

Questo sistema facilita la ricerca e l'aggiornamento dei diagrammi.

### Creare File Mermaid

Segui questi passi per creare un nuovo diagramma:

1. **Crea un file Mermaid**: In VS Code, crea un nuovo file con estensione `.mmd` (es. `nuovo_diagramma.mmd`).
2. **Scrivi il codice Mermaid**: Inserisci direttamente la sintassi Mermaid nel file, senza delimitatori Markdown.
3. **Usa la sintassi appropriata**: Scegli il tipo di diagramma (ER, flowchart, ecc.) e scrivi il codice corrispondente.
4. **Salva il file**: Salvalo nella cartella designata del repository.

#### Esempi di Diagrammi

Ecco alcuni esempi pratici per iniziare. Questi sono codice Mermaid puro da inserire direttamente in un file `.mmd`:

**Entity Relationship Diagram (ERD) semplice**:

```
erDiagram
    ENTITY_A {
        string id PK
        string name
        timestamp createdAt
    }
    ENTITY_B {
        string id PK
        string entityAId FK
        string description
    }
    ENTITY_A ||--o{ ENTITY_B : "has"
```

Questo diagramma rappresenta:
- `ENTITY_A` come entità principale con chiave primaria `id`.
- `ENTITY_B` come entità figlia collegata tramite chiave esterna `entityAId`.
- Una relazione uno-a-molti: un'istanza di `ENTITY_A` può avere molte istanze di `ENTITY_B`.

### Visualizzare il Diagramma in VS Code

Per vedere il diagramma mentre lavori:

1. Apri il file `.mmd` in VS Code.
2. Usa il comando dell'estensione: Premi `Ctrl+Shift+P` (o `Cmd+Shift+P` su Mac) per aprire la palette comandi, cerca "Mermaid Preview: Diagram Preview" e selezionalo.
3. Si aprirà una nuova scheda con l'anteprima interattiva del diagramma.
4. Modifica il codice nel file e salva: l'anteprima si aggiornerà automaticamente.

L'estensione supporta anche zoom, pan e altre interazioni per esplorare diagrammi complessi.

Se l'estensione non funziona, verifica che sia installata, abilitata e che il file abbia estensione `.mmd`.

### Esportare il Diagramma come Immagine

Quando hai bisogno di un'immagine statica per documenti o presentazioni:

1. Apri l'anteprima del diagramma come descritto sopra.
2. Nella scheda dell'anteprima, usa il pulsante "Export" o "Download" fornito dall'estensione per salvare come PNG o SVG.
3. In alternativa, fai uno screenshot dell'anteprima per una soluzione rapida.
4. Rinomina il file seguendo le convenzioni di naming (es. `nome_diagramma_2026_03_10_v1.png`).

L'estensione Mermaid Preview facilita l'esportazione diretta senza bisogno di tool esterni.

### Risorse Aggiuntive

- **Documentazione Mermaid**: [mermaid.js.org](https://mermaid.js.org/) – Guida completa alla sintassi e tipi di diagrammi.
- **Esempi avanzati**: Esplora la galleria su [mermaid.live](https://mermaid.live) per ispirazione.