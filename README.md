# Pn-metrics

Questo repository raccoglie script, query e materiali di supporto per l'analisi e il monitoraggio del prodotto SEND.

## Diagrammi Mermaid

Nel team Metriche vengono adottati diagrammi Mermaid per rappresentare e documentare in modo standardizzato sia i modelli dati sia i flussi applicativi e architetturali.

- **data-models**: diagrammi Entity-Relationship (ER) che descrivono la struttura dei dati, le entità principali, gli attributi e le relazioni tra dataset  
  - Path: `send_diagrams\data-models`

- **diagram-chart**: diagrammi di flusso e sequenza che rappresentano i processi applicativi e le interazioni tra sistemi  
  - Path: `send_diagrams\diagram-chart`

---

## Diagrammi di modello dati

I diagrammi sono basati su file **`.mmd`** ed organizzati per dominio funzionale nella folder:


send_diagrams/
└── data-models/
├── notifiche_e_workflow/
    ├── pn_notifications.mmd
    ├── pn_timeline.mmd
├── postalizzazione/
    ├── pn_ec_richieste_metadati.mmd
└── send_er_model.mmd

---

## Tipologie di diagrammi

I diagrammi sono organizzati su due livelli di dettaglio:

### Diagrammi per singola entità (dettaglio)

- Rappresentano il modello dati completo di una specifica tabella/dominio
- Includono:
  - tutti gli attributi
  - relazioni con le entità collegate
- Esempi:
  - `pn_notifications.mmd`
  - `pn_timeline.mmd`
  - `pn_ec_richieste_metadati.mmd`

Utili per:
- analisi di dettaglio
- allineamento ai data contract
- attività di sviluppo e debugging

---

### Diagramma ER globale (vista sintetica)

- Fornisce una vista d’insieme del dominio SEND
- Include solo:
  - entità principali
  - PK / FK rilevanti
  - relazioni principali

- Esempio:
  - `send_er_model.mmd`

Utile per:
- comprendere il modello logico complessivo
- visualizzare integrazioni tra domini

---

## Naming convention file

Per garantire coerenza e navigabilità, i file seguono le seguenti convenzioni:

### Diagrammi per singola entità

pn_<entità>.mmd

Esempi:
- `pn_notifications.mmd`
- `pn_timeline.mmd`
- `pn_ec_richieste_metadati.mmd`

---

### Linee guida naming
- utilizzare lowercase con underscore (`snake_case`)
- prefisso `pn_` per entità legate al dominio SEND
- nome file allineato alla tabella / modello del data contract
- un file per entità logica

---

## Come scrivere un diagramma Mermaid

1. Creare file `.mmd`
2. Inserire sintassi Mermaid (es. ER, flowchart)
3. Salvare nella cartella del repository

Esempio:

```
erDiagram
ENTITY_A {
  string id PK
  string name
}
ENTITY_B {
  string id PK
  string entityAId FK
}
ENTITY_A ||--o{ ENTITY_B : "has"
```

---

## Header del diagramma

Ogni file deve includere versione e sorgente:

- Esempio per il diagramma **pn_notifications.mmd**:
  - %% version: v1.0.0
  - %% source: dc-pn-Notifications.yaml

> Versionamento dei modelli dati:  
I diagrammi Mermaid devono essere versionati in modo coerente con i rispettivi Data Contract, adottando uno schema di versioning semantico: **vMAJOR.MINOR.PATCH**

| Tipo modifica   | Versione |
|---------------|---------|
| Breaking change | MAJOR |
| Nuovi campi     | MINOR |
| Fix             | PATCH |

---

## Visualizzazione in VS Code

- Aprire file `.mmd`
- `Ctrl + Shift + P` → Mermaid Preview
- Dalla Preview è possibile esportare in PNG/SVG

---

## Riferimenti

- https://mermaid.js.org/
- https://mermaid.live/