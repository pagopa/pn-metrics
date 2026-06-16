# Pn-metrics

Questo repository raccoglie script, query e materiali di supporto per l'analisi e il monitoraggio del prodotto SEND.

## Mermaid Diagrams – Linee guida essenziali

### Obiettivo
Gestire diagrammi Mermaid versionati, coerenti con i data contract e facilmente tracciabili nel repository.

## Struttura repository

I diagrammi sono organizzati per dominio funzionale nella folder **send_diagrams**.

**Esempio struttura repository**
```
send_diagrams/
└── notifiche_e_workflow/
    ├── notifiche_e_workflow.mmd
    ├── notifiche_e_workflow_13_03_26_v1.0.0.png
    └── notifiche_e_workflow_16_06_26_v1.1.0.png
```

## Principi progettuali
- Il file `.mmd` è la sorgente unica
- Le immagini sono snapshot versionati
- Tutti i file relativi allo stesso diagramma stanno nella stessa cartella
- Nessuna espansione di oggetti complessi

## Workflow

1. Creare file `.mmd`
2. Verifica tramite preview
3. Export e aggiornamento del diagramma

### Creazione
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

### Visualizzazione (VS Code)
- Aprire file `.mmd`
- `Ctrl+Shift+P` → Mermaid Preview
- Salvare per aggiornare

### Esportazione
- Export da preview (PNG/SVG)
- Applicare naming standard

## Naming

### File sorgente
```
<dominio>.mmd
```
Esempio:
```
notifiche_e_workflow.mmd
```

### Immagini
```
<nome>_<DD_MM_YY>_v<X.Y.Z>.png
```
Esempio:
```
notifiche_e_workflow_16_06_26_v1.1.0.png
```

## Versionamento

Il diagramma va allineato ai rispettivi Data Contract secondo lo schema:

```
vMAJOR.MINOR.PATCH
```

| Tipo modifica   | Versione |
|-----------------|----------|
| Breaking change | MAJOR    |
| Nuovi campi     | MINOR    |
| Fix             | PATCH    |

**Esempio**

- Versione iniziale: `notifiche_e_workflow_13_03_26_v1.0.0.png`
- Aggiornamenti:
  - aggiunta `senderPriority`
  - aggiunta `reworkId`
- Nuova versione: `notifiche_e_workflow_16_06_26_v1.1.0.png`

## Riferimenti

- https://mermaid.js.org/
- https://mermaid.live/

