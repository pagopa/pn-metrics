# Pn-metrics

Questo repository raccoglie script, query e materiali di supporto per l'analisi e il monitoraggio del prodotto SEND.

## Diagrammi Mermaid

Nel team Metriche vengono adottati diagrammi Mermaid per rappresentare e documentare in modo standardizzato sia i modelli dati sia i flussi applicativi e architetturali.

- **data-models**: diagrammi Entity-Relationship (ER) che descrivono la struttura dei dati, le entità principali, gli attributi e le relazioni tra dataset (es. Notifications, Timeline, richieste, relazioni 1:N / 1:1)
  - Path: send_diagrams\data-models


- **diagram-chart**: diagrammi di flusso e sequenza che rappresentano i processi applicativi, le pipeline dati e le interazioni tra sistemi (es. ingestion, data quality, orchestrazione servizi AWS, gestione errori e notifiche)
  - Path: send_diagrams\diagram-chart

### Diagrammi di modello dati

I diagrammi sono basati su file **.mmd** ed organizzati per dominio funzionale nella folder **send_diagrams\data-models**.

**Esempio struttura repository**
```
send_diagrams/
└── data-models/
    └── notifiche_e_workflow/
        └── notifiche_e_workflow.mmd
```

### Diagrammi modelli dati presenti

- **notifiche_e_workflow**: rappresentazione del dominio notifiche e timeline,
  incluse le relazioni tra Notifications, Timeline e Notification Request

### Come scrivere un diagramma Mermaid

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

#### Header del diagramma
Ogni file deve includere versione e sorgente:

**Esempio**
  ```
  %% version: v1.1.0
  %% source: data-contract dc-pn-Notifications.yaml, dc-pn-timeline.yaml
  ```

> Versionamento dei modelli dati: I diagrammi Mermaid devono essere versionati in modo coerente con i rispettivi Data Contract, adottando uno schema di versioning semantico: **vMAJOR.MINOR.PATCH**

| Tipo modifica   | Versione |
| --------------- | -------- |
| Breaking change | MAJOR    |
| Nuovi campi     | MINOR    |
| Fix             | PATCH    |

### Come visualizzazione in VS Code un diagramma Mermaid
- Aprire file `.mmd`
- `Ctrl+Shift+P` → Mermaid Preview
- Dalla Preview è possibile fare Export da preview (PNG/SVG)

### Riferimenti

- https://mermaid.js.org/
- https://mermaid.live/