# Pn-metrics

Questo repository raccoglie script, query e materiali di supporto per l'analisi e il monitoraggio del prodotto SEND.

## Mermaid Diagrams – Quick Guide

Questa guida descrive in modo essenziale come creare, gestire ed esportare diagrammi Mermaid in Visual Studio Code tramite l'estensione Mermaid Preview.

### Workflow consigliato

Per mantenere i diagrammi ordinati, aggiornati e coerenti con il repository, si suggerisce il seguente flusso:

1. **Scrittura e manutenzione**: salvare i diagrammi come file `.mmd` direttamente nel repository, così da versionarli insieme al codice.
2. **Visualizzazione in sviluppo**: utilizzare Mermaid Preview per controllare il risultato grafico durante la modifica.
3. **Esportazione**: generare PNG o SVG solo quando necessario per documentazione esterna o presentazioni.

Questo approccio semplifica la manutenzione e garantisce l'allineamento tra documentazione e contenuti versionati.

### Prerequisiti

Prima di procedere, verificare di disporre di:

- **Visual Studio Code**: scaricabile da [code.visualstudio.com](https://code.visualstudio.com/).
- **Estensione Mermaid Preview**:
  - installazione tramite pannello Extensions (`Ctrl+Shift+X`) cercando “Mermaid Preview”;
  - link diretto: https://marketplace.visualstudio.com/items?itemName=vstirbu.vscode-mermaid-preview;
  - funzionalità principali: anteprima interattiva, esportazione e personalizzazione del tema.
- **Posizione corretta nel repository**: salvare i file `.mmd` nella cartella più adatta al contenuto rappresentato.

### Convenzioni di naming

Per favorire ordine e tracciabilità, adottare le seguenti convenzioni:

- **File Mermaid (`.mmd`)**:
  - il nome deve descrivere il workflow o il modulo logico rappresentato, seguito dal tipo di diagramma;
  - esempio: `timeline_notifications_er.mmd`.

- **Immagini esportate (PNG o SVG)**:
  - utilizzare lo stesso nome del file `.mmd`, aggiungendo data di esportazione e versione;
  - esempio: `timeline_notifications_er_10_03_2026_v1.png`.

Questa convenzione rende più semplice individuare, aggiornare e confrontare i diagrammi nel tempo.

### Creazione di un file Mermaid

Per creare un nuovo diagramma:

1. creare un file con estensione `.mmd`, ad esempio `nuovo_diagramma.mmd`;
2. inserire direttamente la sintassi Mermaid;
3. scegliere il tipo di diagramma appropriato, ad esempio ER o flowchart;
4. salvare il file nella cartella designata del repository.

#### Esempio

Di seguito un esempio minimale di diagramma ER:

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

Il diagramma rappresenta:

- `ENTITY_A` come entità principale con chiave primaria `id`;
- `ENTITY_B` come entità correlata tramite chiave esterna `entityAId`;
- una relazione uno-a-molti tra `ENTITY_A` e `ENTITY_B`.

### Visualizzazione in VS Code

Per aprire l'anteprima del diagramma:

1. aprire il file `.mmd` in VS Code;
2. richiamare la Command Palette con `Ctrl+Shift+P`;
3. selezionare il comando **Mermaid Preview: Diagram Preview**;
4. aggiornare e salvare il file per vedere l'anteprima ricaricarsi automaticamente.

L'anteprima supporta anche operazioni di navigazione utili, come zoom e spostamento.

Se la preview non è disponibile, verificare che l'estensione sia installata, attiva e che il file abbia estensione `.mmd`.

### Esportazione come immagine

Quando serve una versione statica del diagramma:

1. aprire l'anteprima;
2. usare il comando di esportazione dell'estensione per salvare in PNG o SVG;
3. rinominare il file secondo la convenzione definita.

In alternativa, per esigenze rapide, è possibile acquisire uno screenshot dell'anteprima.

### Risorse aggiuntive

- **Documentazione Mermaid**: [mermaid.js.org](https://mermaid.js.org/)
- **Esempi e playground**: [mermaid.live](https://mermaid.live)