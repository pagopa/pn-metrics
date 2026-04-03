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
  - il nome deve descrivere il workflow o il modulo logico rappresentato, seguito dal **tipo di diagramma**;
  - esempio: `notifications_timeline_er.mmd`.

- **Immagini esportate (PNG o SVG)**:
  - utilizzare lo stesso nome del file Mermaid, dalla data e una versione;
  - esempio: `notifications_timeline_er_13_03_26_v1.png`.

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

## Automazione della rilevazione delle modifiche nei modelli dati 
Automazione per il monitoring continuo e l'audit dei data contract DynamoDB distribuiti su molteplici repository backend.

### Contesto e Problema da Risolvere
Il team metriche di SEND è responsabile della definizione, manutenzione ed evoluzione dei **Data Contract**. Attualmente, tuttavia, non è disponibile uno schema dati centralizzato che consenta una visione chiara, aggiornata e consistente della struttura delle tabelle presenti su DynamoDB.

Lo stato attuale è caratterizzato da una forte distribuzione delle informazioni: i modelli dati sono definiti all’interno di molteplici repository backend, sotto forma di entity Java, senza un meccanismo strutturato che ne permetta l’estrazione, la normalizzazione e la consultazione centralizzata.

In questo contesto, risulta complesso:

* ottenere una visione unificata del modello dati complessivo
* garantire l’allineamento tra implementazione backend e Data Contract
* tracciare in modo efficace le evoluzioni delle strutture dati

Considerata questa frammentazione, emerge la necessità di attingere direttamente al livello backend, per costruire un modello dati centralizzato, aggiornato automaticamente che sia di supporto per la gestione dei Data Contract.

L’obiettivo è quindi progettare e implementare una pipeline automatizzata che abiliti la rilevazione (detection) delle modifiche ai modelli dati, monitorando i branch principali (main) dei repository backend e intercettando in modo sistematico ogni variazione strutturale rilevante.

### Struttura della Repository

Di seguito, la struttura della cartella `data-discovery` con una descrizione sintetica di ogni file.

```
data-discovery/
├── main.py                        # Entry point: legge la config YAML e orchestra il processing per ogni repository configurato
├── core.py                        # Cuore applicativo: associazione DAO-tabella, propagazione entity, costruzione schema, confronto diff e generazione changes
├── github_utils.py                # Client GitHub REST: listing cartelle, download file Java/properties, lettura commit SHA, scan ricorsiva
├── utils.py                       # Funzioni helper: parsing classi @DynamoDbBean, estrazione attributi/annotazioni, normalizzazione nomi per fuzzy matching
├── proposta.md                    # Documento di progetto: obiettivi, flusso logico, mapping, output e limiti noti
├── config/
│   └── config.yaml                # Configurazione centralizzata: organizzazione GitHub, elenco repository target, pattern DAO/entity, regex tabelle DynamoDB
```

### Workflow Logico

#### 1. Scaricamento e Scansione Sorgenti

- **Input**: configurazione YAML (`config/config.yaml`) con organizzazione GitHub, path repository, branch e pattern di ricerca.
- **Processo**: download ricorsivo tramite API GitHub dei file `.java` (DAO e entity) e file di configurazione (`application.properties`).
- **Output**: collection di file Java e properties organizzati per repo.

#### 2. Parsing e Analisi

- **Estrazione tabelle DynamoDB**: ricerca tramite regex configurabile nei file `application.properties` (pattern: `[tablename|table-name|table|tablev2]=<nome_tabella>`).
- **Parsing DAO**: analizzare file che corrispondono ai pattern DAO (es. `*DaoDynamo.java`, `*DAOImpl.java`) per estrarre:
  - Nome file DAO
  - Riferimenti a entity (tramite tipo usato, nomi come `*Entity`)
  - Chiavi di configurazione per associare a tabelle specifiche
- **Parsing entity**: identificare classi annotate con `@DynamoDbBean` e estrarre:
  - Nome entity
  - Attributi con tipo e annotazioni
  - Chiavi primarie/secondarie (tramite `@DynamoDbPartitionKey`, `@DynamoDbSortKey`)
  - Percorso file sorgente

#### 3. Mapping Logico

- **Associazione tabella-DAO** (in ordine di priorità):
  1. Presenza della chiave di configurazione nel sorgente DAO (`@Value` o costanti)
  2. Presence letterale del nome tabella nel DAO
  3. Similarità fuzzy tra nome tabella e nome file DAO
- **Associazione tabella-entity**: per ogni DAO identificato, collega entity effettivamente referenziate (ricorsivamente tramite composizione).
- **Fallback per entity orfane**: matching fuzzy tra nome tabella e nome entity con chiavi DynamoDB.
- **Gestione entity non associate**: elenca separatamente entity mai collegate a tabelle.

#### 4. Generazione Output

- **Snapshot JSON**: per ogni repo, file `schema_<timestamp>.json` contiene:
  - Metadati (repo, branch, commit hash, timestamp)
  - Tabelle con DAO associati, entity correlate e dettagli attributi
  - Entity orfane
- **Diff automatico**: se schema cambia, genera `changes_<timestamp>.txt` con:
  - Attributi aggiunti, rimossi, modificati (con dettaglio tipo precedente/nuovo)
  - Intestazione con repo, branch, timestamp corrente e precedente
- **Persistenza**: file salvati in `data-discovery/reports/<repo>/`

### Roadmap Copertura Repository

Tracciamento dello stato di integrazione per ogni repository backend monitorato dalla pipeline.
I pattern DAO e entity seguono le convenzioni globali definite in `config/config.yaml`.

| Repository | Path DAO | Properties Path | Branch | Status |
|---|---|---|---|---|
| **pn-delivery** | `src/main/java/it/pagopa/pn/delivery/middleware/notificationdao` | `config/application.properties` | `main` | ✅ Integrato |
| **pn-delivery-push** | `src/main/java/it/pagopa/pn/deliverypush/middleware/dao` | `config/application.properties` | `main` | ✅ Integrato |
| **pn-radd-alt** | `src/main/java/it/pagopa/pn/radd/middleware/db` | `config/application.properties` | `main` | ✅ Integrato |
| **pn-mandate** | — | — | `main` | ⏳ TODO |
| **pn-user-attributes** | — | — | `main` | ⏳ TODO |

> **Pattern DAO globali**: `*DaoDynamo.java`, `*DAOImpl.java`  
> **Pattern cartelle entity**: `entity`, `entities`  
> **Regex tabelle**: `([\\w\\.-]+(?:table-name|tablename|table|tablev2))=(\\w[\\w-]*)`

### Prossimi Passi

| Task | Descrizione | Status |
|------|-------------|--------|
| **Folder di test** | Creazione suite test unitari per discovery, parser, mapper e output_generator. Fixture con file Java mock e config YAML di prova. | ⏳ TODO |
| **GitHub Actions** | Implementazione workflow automatico schedulato (daily/weekly) per eseguire discovery su repo configurati e commitare snapshot/diff in branch dedicato o notificare su Slack. | ⏳ TODO |
| **Risoluzione edge-case** | Tuning fuzzy matching per convenzioni diverse (plurale/singolare, suffissi custom, camel case/underscore). Validazione con dataset reale da pn-delivery, pn-timeline-service. | ⏳ TODO |
| **Notifiche integrate** | Aggiunta canale notifiche (Slack/email) per alert su schemi modificati, con logica di escalation e policy di review. | ⏳ TODO |
| **Validazione schema-uso** | Confronto automatico tra schema estratto e utilizzo effettivo nei servizi applicativi (tramite static analysis). | ⏳ TODO |


Tracciamento dello stato di integrazione per ogni repository backend monitorato dalla pipeline.
I pattern DAO e entity seguono le convenzioni globali definite in `config/config.yaml`.

| Repository | Path DAO | Properties Path | Branch | Status |
|---|---|---|---|---|
| **pn-delivery** | `src/main/java/it/pagopa/pn/delivery/middleware/notificationdao` | `config/application.properties` | `main` | ✅ Integrato |
| **pn-delivery-push** | `src/main/java/it/pagopa/pn/deliverypush/middleware/dao` | `config/application.properties` | `main` | ✅ Integrato |
| **pn-radd-alt** | `src/main/java/it/pagopa/pn/radd/middleware/db` | `config/application.properties` | `main` | ✅ Integrato |
| **pn-mandate** | — | — | `main` | ⏳ TODO |
| **pn-user-attributes** | — | — | `main` | ⏳ TODO |

> **Pattern DAO globali**: `*DaoDynamo.java`, `*DAOImpl.java`  
> **Pattern cartelle entity**: `entity`, `entities`  
> **Regex tabelle**: `([\\w\\.-]+(?:table-name|tablename|table|tablev2))=(\\w[\\w-]*)`