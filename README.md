# Pn-metrics

Questo repository raccoglie script, query e materiali di supporto per l'analisi e il monitoraggio del prodotto SEND.

## Diagrammi Mermaid

Nel team Metriche vengono adottati diagrammi Mermaid per rappresentare e documentare in modo standardizzato sia i modelli dati sia i flussi applicativi e architetturali.

- **data-models**: diagrammi Entity-Relationship (ER) che descrivono la struttura dei dati, le entità principali, gli attributi e le relazioni tra dataset  
  - Path: `send_diagrams\data-models`

- **diagram-chart**: diagrammi di flusso e sequenza che rappresentano i processi applicativi e le interazioni tra sistemi  
  - Path: `send_diagrams\diagram-chart`

### Prerequisiti

Per creare e visualizzare i diagrammi Mermaid è necessario avere:

- Visual Studio Code installato
- estensione Mermaid Chart per VS Code installata
- file `.mmd` salvati nella struttura prevista

**Estensione consigliata:**
- https://marketplace.visualstudio.com/items?itemName=MermaidChart.vscode-mermaid-chart

### Data Models Diagrams

I diagrammi sono basati su file `.mmd` Mermaid e sono organizzati nella folder `send_diagrams` ed organizzati su due livelli di dettaglio.

- diagrammi ER per dominio funzionale
- diagramma ER globale SEND

#### Diagrammi per dominio funzionale

Rappresentano il modello dati di uno specifico dominio SEND.

**Esempio:**

- `notifiche_e_workflow.mmd`
Ogni diagramma, per una specifica area funzionale, include:

- versione del diagramma
- sorgenti utilizzate
- entità principali del dominio
- oggetti annidati di primo livello rilevanti
- relazioni tra entità
- attributi principali
- vincoli PK / FK / NOT NULL quando disponibili


#### Diagramma ER globale

Fornisce una vista sintetica del modello dati SEND.

**Esempio:**

- `send_er_model.mmd`

Include:

- entità principali
- chiavi primarie e chiavi esterne rilevanti
- relazioni principali tra domini

Utili per:

- comprendere il modello logico complessivo
- visualizzare le relazioni principali tra domini
- supportare analisi trasversali

## Configurazione Mermaid

Ogni file `.mmd` deve includere la configurazione Mermaid iniziale.

Configurazione standard:

```yaml
---
config:
  layout: elk
  theme: base
  themeVariables:
    background: "#FFFFFF"
    labelBackgroundColor: "#FFFFFF"
    entityBkgColor: "#FFFFFF"
    attributeBkgColor: "#FFFFFF"
    primaryColor: "#FFFFFF"
---

## Riferimenti

- https://mermaid.js.org/
- https://mermaid.live/