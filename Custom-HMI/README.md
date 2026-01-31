# Architettura HMI - Semplified Secure Water Treatment System

## Panoramica
Interfaccia utente (HMI) custom permette il monitoraggio dei parametri del sistema Simplified Secure Water Treatment (SSWaT) in tempo reale ed in modalita' esclusivamente Read-Only. 
L'applicazione e' composta da un frontend web leggero e reattivo e da un backend dedicato alla lettura dei dati dalle PLC.

## Processo fisico
![phy_proc_sswat](/images/simplified_SWAT_system.png)

## Immagine HMI
![hmi_sswat](/images/hmi.png)

## Diagramma dell'Architettura
```[ Browser Client ] <-- (API Fetch) --> [ Express.js API Server ] <-- (Modbus) --> [ PLC1, PLC2, PLC3 ]```

## Scelte progettuali principali

### 1. Frontend: Framework Tailwind CSS
Framework che permette di sviluppare rapidamente un'interfaccia utente responsive e ricca di indicatori visivi. La sua natura utility-first accelera la creazione di layout per visualizzare dati senza la necessita' di una logica complessa di gestione del UI.

### 2. Backend: Node.js Express.js
Node.js e' adatto a gestire le numerose connessioni simultanee e non bloccanti verso le PLC. Exepress.js fornisce una base minima per esporre un'API RESTful semplice e dedicata esclusiavamente alla fornitura di dati.

### 3. Protocollo di comunicazione: Modbus-serial
Scelta obbligatoria dallo standard industraile Modbus utilizzato dalle PLC target. La libreria modbus-serial e' stata configurata per utilizzare esclusivamente la funzionalita' di lettura dei dati.

## Struttura del Codebase (semplificata)
```
Custom-HMI/
├── backend
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js
├── frontend
│   ├── Dockerfile
│   └── index.html
├── plc_1_docker
├── plc_2_docker
├── plc_3_docker
├── automation
└── physical_sim_docker
```

---
# Descrizione del sistema

Il sistema di prova è costituito da sei container Docker, che sono i seguenti:
- Container del backend: esegue un server Express.js che fornisce un'API RESTful per la lettura dei dati dalle PLC.
- Container del frontend: fornisce un'interfaccia utente per visualizzare i dati ottenuti dal backend.
- Tre container PLC virtuali: ogni container esegue un PLC virtuale implementato tramite OpenPLC. Questi PLC monitorano i sensori e controllano gli attuatori all'interno del sistema di serbatoi simulato. Inoltre, il container PLC-2 include un broker Python per simulare la comunicazione tra PLC-2 e PLC-1.
- Container del simulatore di processo fisico: questo container esegue un simulatore di processo fisico Python che utilizza la libreria SciPy ed equazioni differenziali di primo ordine per modellare i processi fisici che si verificano nel sistema di serbatoi di trattamento dell'acqua.

## Descrizione dei file principali
- build_system.sh: uno script Bash che crea immagini Docker ed esegue i container Docker del sistema (PLC, Custom HMI, backend e simulatore basato su Python).
- start_system.sh: uno script Bash che avvia i container Docker del sistema.
- stop_system.sh: uno script Bash che arresta i container Docker del sistema.

## Creazione di immagini Docker ed esecuzione di container

```bash
  sh ./build_system.sh
```

## Avvio del sistema

```bash
  sh ./start_system.sh
```

## Arresto del sistemam

```bash
  sh ./stop_system.sh
```

## Nota importante sulle istanze OpenPLC
Quando si avvia il sistema per la prima volta, è necessario fare clic sul pulsante “Salva modifiche” nella pagina “Hardware” per ciascuna istanza OpenPLC. Quindi è necessario riavviare il sistema.
