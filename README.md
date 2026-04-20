# Notion Quotes Widget

Widget macOS che legge frasi da un database Notion e le mostra a rotazione tramite WidgetKit.

## Architettura

- App macOS SwiftUI: configura token Notion e mantiene una cache locale solo per anteprima e test nell'app.
- Widget macOS: si configura direttamente nelle impostazioni del widget e legge Notion in autonomia.
- Nessun App Group: il widget non dipende più da storage condiviso con l'app.

## Limite importante di macOS WidgetKit

I widget macOS non sono pensati per aggiornamenti al secondo o troppo frequenti. In questo progetto l'intervallo minimo è impostato a `5` minuti per restare allineati al comportamento atteso di WidgetKit.

## Requisiti

- macOS 14+
- Xcode 16+
- `xcodegen` installato (`brew install xcodegen`)
- Integrazione Notion con accesso al database desiderato

## Configurazione Notion

Nel database Notion devono esistere due proprietà testuali separate:

- una per il titolo
- una per la fonte

Per entrambe il progetto supporta proprietà di tipo:

- `title`
- `rich_text`
- `formula` che restituisce una stringa

## Setup

1. Se vuoi usare bundle identifier reali, aggiorna `project.yml`.
2. Genera il progetto Xcode:

```bash
cd /Users/jonathanlamela/Desktop/personal-projects/NotionQuotesWidget
xcodegen generate
open NotionQuotesWidget.xcodeproj
```

1. In Xcode, abilita il signing per app e widget extension.
2. Avvia l'app, inserisci:
   - Notion integration token
   - database ID
   - nome della proprietà titolo
   - nome della proprietà fonte
   - intervallo di rotazione in minuti
3. Premi `Sincronizza da Notion` se vuoi usare l'app come anteprima locale.
4. Aggiungi il widget `Notion Quotes` al desktop o al Centro Notifiche.
5. Apri la configurazione del widget e inserisci direttamente lì:
   - token Notion
   - database ID
   - nome campo titolo
   - nome campo fonte
   - intervallo di rotazione

## Se il widget non appare

- Verifica che app e widget extension siano firmati con lo stesso team Apple in Xcode.
- Esegui di nuovo `xcodegen generate` se hai modificato `project.yml`.
- Avvia l'app una volta da Xcode, poi apri il selettore widget di macOS e cerca `Notion Quotes`.
- Se ancora non compare, elimina l'app da `DerivedData`, rilanciala e riprova.

### Checklist Xcode: Signing & Capabilities

Per il target `NotionQuotes`:

- `Signing & Capabilities > Team`: deve essere il tuo team Apple.
- `Signing & Capabilities > Automatically manage signing`: attivo.
- `Signing & Capabilities > App Sandbox`: attivo.
- `Signing & Capabilities > Network > Outgoing Connections (Client)`: attivo.

Per il target `NotionQuotesWidgetExtension`:

- `Signing & Capabilities > Team`: deve essere lo stesso team del target app.
- `Signing & Capabilities > Automatically manage signing`: attivo.
- `Signing & Capabilities > App Sandbox`: attivo.
- `Signing & Capabilities > Network > Outgoing Connections (Client)`: attivo.

Controlli finali:

- `General > Bundle Identifier`: app e widget devono essere univoci, ma coerenti con il tuo team.
- Dopo aver cambiato signing o capabilities, esegui di nuovo `xcodegen generate` solo se hai modificato `project.yml`, poi fai `Product > Clean Build Folder`.

## Note operative

- Il token Notion nell'app è salvato nei `UserDefaults` locali dell'app solo per mantenere il setup semplice. Per produzione conviene usare Keychain.
- Il widget interroga direttamente Notion e non dipende da App Groups o da una cache condivisa.
- Il widget rifetch-a Notion a ogni intervallo configurato, non solo quando viene ricreato manualmente.
- La cache dell'app resta utile solo come anteprima locale e per verificare rapidamente che la query Notion funzioni.
