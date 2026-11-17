# Daybook: návrh aplikace

Datum: 2026-11-17. Stav: schváleno uživatelem v rozhovoru, čeká na přečtení této písemné verze.

Produktová fakta (pro koho, proč, principy) jsou v `PRODUCT.md`. Tento dokument popisuje, co se staví a jak.

## 1. Cíl

Kalendář pro iPhone, iPad a Mac, který zobrazuje kalendáře z iCloudu, Exchange a Googlu včetně sdílených Google kalendářů. V měsíčním pohledu je v políčku každého dne vidět všechno, co je na ten den naplánováno v zapnutých kalendářích, a měsíc zůstává čitelný, i když je plný.

## 2. Rozhodnutí

| Oblast | Rozhodnutí |
|---|---|
| Zdroj kalendářů | EventKit nad účty přidanými v systémovém Nastavení. Daybook se ke službám sám nepřihlašuje. |
| Kategorie událostí | Vlastní data aplikace ve SwiftData, synchronizovaná přes CloudKit (soukromá databáze uživatele). |
| Platformy | SwiftUI, iOS 26 a macOS 26, nativní macOS target (ne Catalyst). |
| Projekt | XcodeGen (`project.yml`), vygenerovaný `.xcodeproj` se necommituje. |
| Distribuce | Veřejně přes App Store. |
| Pozvánky | Vlastní editor události; na iOS a iPadOS tlačítko „Pozvat účastníky“ otevře systémový editor. Na macOS se účastníci jen zobrazují. |
| Vizuální směr | Noční schéma linek (viz oddíl 6). |
| Jazyky | Čeština a angličtina, String Catalog. |

## 3. Architektura

```
project.yml
App/                       aplikační target (iOS + macOS), jen SwiftUI a napojení na systém
  DaybookApp.swift
  Shell/                   kořenové rozvržení, postranní panel, lišta, přepínač pohledů
  Month/  Week/  Day/      tři pohledy
  Search/                  vyhledávání
  Editor/                  editor události, nový kalendář, systémový editor na iOS
  Categories/              správa a přiřazování kategorií
  Onboarding/              první spuštění, oprávnění
  Theme/                   barvy, písmo, komponenty linek a zastávek
  System/                  EventKitCalendarStore, SwiftData kontejner
Packages/DaybookCore/      Swift balíček bez UI a bez EventKitu
  Sources/DaybookCore/
    Model/                 CalendarInfo, EventInfo, EventKey, Category, SourceKind
    Store/                 protokol CalendarStore, InMemoryCalendarStore pro testy
    Layout/                MonthLayout, TimeGridLayout
    Filter/                VisibilityFilter (zapnuté kalendáře a kategorie)
    Search/                EventSearch
  Tests/DaybookCoreTests/
```

Pravidlo závislostí: `DaybookCore` nezná SwiftUI, EventKit ani SwiftData. Aplikační target převádí systémové typy na hodnotové typy z balíčku a zpět. Díky tomu se celá logika testuje přes `swift test` bez simulátoru.

### 3.1 Typy v DaybookCore

- `CalendarInfo`: `id` (EventKit `calendarIdentifier`), název, barva (RGBA), `sourceTitle`, `sourceKind` (`icloud`, `exchange`, `google`, `local`, `subscribed`, `other`), `isReadOnly`, `isShared`.
- `EventInfo`: `key: EventKey`, `calendarID`, název, začátek, konec, `isAllDay`, místo, poznámka, účastníci (jméno, e-mail, stav), opakování (jen pro zobrazení), `isEditable`.
- `EventKey`: `externalID` (EventKit `calendarItemExternalIdentifier`, stabilní mezi zařízeními) a `occurrenceStart` (pro výskyty opakované události). Kategorie se vážou na `EventKey`.
- `Category`: `id` (UUID), název, symbol (název SF Symbolu), pořadí.
- `CalendarStore` (protokol): seznam kalendářů; události v intervalu; vytvořit, upravit a smazat událost (s rozsahem „jen tento výskyt“ nebo „i budoucí“); vytvořit kalendář; změnit barvu kalendáře; proud změn.

### 3.2 Napojení na systém

- `EventKitCalendarStore` implementuje `CalendarStore` nad `EKEventStore`. Žádá plný přístup (`requestFullAccessToEvents`), poslouchá `EKEventStoreChanged` a po změně znovu načte viditelný rozsah.
- `sourceKind` se odvozuje z `EKSource.sourceType` a názvu zdroje (Google účty jsou v EventKitu typu CalDAV). `isShared` u Google kalendářů: kalendář v Google zdroji, který není primární nebo je jen pro čtení.
- SwiftData kontejner s CloudKitem drží `CategoryRecord` a `CategoryAssignmentRecord` (`externalID`, `occurrenceStart`, `categoryID`). Model respektuje omezení CloudKitu: žádné unikátní omezení, všechny atributy s výchozí hodnotou nebo volitelné.
- Vypnuté kalendáře a naposledy použitý pohled se ukládají do `UserDefaults` pro každé zařízení zvlášť (identifikátory kalendářů jsou lokální).

## 4. Obrazovky

### 4.1 Kostra

- Mac a iPad: `NavigationSplitView`. Vlevo postranní panel, vpravo aktuální pohled. V liště název období, šipky zpět a vpřed, „Dnes“, přepínač Den / Týden / Měsíc (segmentovaný), vyhledávání, „+“ pro novou událost.
- iPhone: jeden sloupec s `NavigationStack`. Přepínač pohledů v liště, kalendáře a kategorie v listu vysunutém zdola, vyhledávání přes `.searchable`.
- Mac: klávesové zkratky ⌘1, ⌘2, ⌘3 (pohledy), ⌘T (dnes), ⌘N (nová událost), ⌘F (hledání), šipky pro posun období.

### 4.2 Postranní panel

- Kalendáře seskupené podle účtu (iCloud, Exchange, Google, ostatní). U každého zaškrtávátko v barvě kalendáře, název, u sdílených popisek „sdílený“, u kalendářů jen pro čtení symbol zámku.
- Kontextová nabídka kalendáře: změnit barvu, zobrazit jen tento.
- Pod kalendáři oddíl Kategorie: každá se symbolem a zaškrtávátkem; slouží jako filtr. Položka „Bez kategorie“ je také filtr. Dole „Nová kategorie“ a „Nový kalendář“.

### 4.3 Měsíc

Hlavní slib produktu. Pravidla:

1. Mřížka sedm sloupců, týden začíná podle místního nastavení.
2. Výška řádku týdne = výška nejplnějšího dne v tom týdnu. Žádný den se neořezává a nikde není „+N dalších“.
3. Měsíc se posouvá svisle; plynule navazují sousední měsíce.
4. V buňce nahoře číslo dne, pod ním celodenní a vícedenní události, pak časované události seřazené podle začátku.
5. Časovaná událost je jeden řádek: zastávka na svislé lince v barvě kalendáře, čas, název, případně symbol kategorie. Když je vedle sebe víc dnů s událostmi téhož kalendáře, linka běží souvisle.
6. Vícedenní událost je vodorovná linka přes všechny své dny, s názvem na začátku a na začátku každého dalšího týdne. Vícedenní události drží v celém týdnu stejnou výškovou pozici.
7. Dny mimo aktuální měsíc jsou ztlumené, víkendy mají lehce tmavší podklad.
8. Dnešek má číslo v bílém přestupním kruhu.
9. iPhone: řádek události nese jen zastávku a název (bez času), užší písmo; klepnutí na den otevře list se seznamem dne v plné podobě. Mac a iPad: klik na událost otevře detail v popoveru, dvojklik na prázdné místo dne založí událost.
10. Při velkém písmu (Dynamic Type) řádky rostou, nic se neskrývá; měsíc je jen delší.

`MonthLayout` v balíčku dostane události, viditelný měsíc, kalendář (`Calendar`) a vrátí pro každý týden: přiřazení vícedenních událostí do pruhů, seřazené události každého dne a počet řádků týdne. Pohled z toho jen kreslí.

### 4.4 Týden a den

- Svislá časová osa, nahoře pruh celodenních událostí (roste podle počtu, neořezává se).
- Překrývající se události se dělí do sloupců vedle sebe (`TimeGridLayout`).
- Událost je blok v barvě kalendáře s linkou vlevo, názvem, časem a místem.
- Čára aktuálního času s přestupním kruhem.
- Týden na iPhonu: vodorovně posuvný, vidět jsou tři dny najednou. Den: jeden sloupec, na Macu vedle něj malý měsíční navigátor.

### 4.5 Vyhledávání

- Hledá v názvu, místě, poznámce a jménech a e-mailech účastníků, bez ohledu na diakritiku a velikost písmen.
- Rozsah: pět let zpět a pět let dopředu, načítaný po čtyřletých úsecích (omezení predikátu EventKitu).
- Respektuje zapnuté kalendáře; přepínač „Hledat i ve vypnutých“.
- Výsledky seskupené po dnech, nejbližší budoucí nahoře, minulé pod nimi. Výběr výsledku přejde na den události.

### 4.6 Editor události

- List (iOS) nebo okno listu (macOS) s formulářem: název, kalendář (jen zapisovatelné), celodenní, začátek, konec, časové pásmo, opakování (nikdy, denně, týdně, měsíčně, ročně, konec opakování), upozornění, místo, URL, poznámka, kategorie.
- Účastníci: seznam se stavem odpovědi, jen ke čtení. Na iOS a iPadOS tlačítko „Pozvat účastníky“ uloží rozpracovanou událost a otevře `EKEventEditViewController`.
- Úprava a smazání opakované události se ptá na rozsah (jen tento výskyt, tento a budoucí).
- U události z kalendáře jen pro čtení je formulář zamčený a jde měnit jen kategorie.

### 4.7 Nový kalendář

- Název, barva, účet. Nabízí se jen zdroje, kde EventKit vytvoření dovolí (iCloud, Exchange, lokální). U Google účtu vysvětlení, že kalendář je potřeba založit u Googlu a zapnout pro synchronizaci.

### 4.8 Kategorie

- Správa: přidat, přejmenovat, změnit symbol, seřadit, smazat (smazání odebere přiřazení).
- Přiřazení: v editoru, v detailu a přes kontextovou nabídku události. Událost může mít víc kategorií.
- U opakované události se kategorie přiřazuje celé sérii, pokud uživatel nezvolí jen jeden výskyt.

### 4.9 První spuštění

- Jedna obrazovka: co Daybook dělá, proč potřebuje přístup ke kalendářům, tlačítko pro systémový dotaz.
- Po povolení rovnou měsíc. Když v systému nejsou žádné kalendářové účty, prázdný stav s návodem, kde účet přidat.

## 5. Stavy a chyby

- Přístup odepřen nebo omezen: celoobrazovkové vysvětlení s tlačítkem do Nastavení.
- Uložení selže (kalendář mezitím zmizel, účet odmítl změnu): upozornění s textem chyby, formulář zůstane otevřený s daty.
- iCloud není přihlášený nebo dostupný: kategorie fungují lokálně, v nastavení kategorií řádek se stavem synchronizace.
- Událost s přiřazenou kategorií už neexistuje: přiřazení se ponechá (událost se může vrátit po synchronizaci), nezobrazuje se.
- Načítání: mřížka se kreslí hned, události dotečou; žádný blokující spinner.

## 6. Vizuální směr: Noční schéma linek

- Tmavý vzhled: půlnočně modrá plocha, porcelánově bílé texty a zastávky. Světlý vzhled: porcelánová plocha, tmavě modré texty, stejné barvy linek.
- Kalendář je linka. Barvu určuje barva kalendáře z EventKitu; v tmavém i světlém vzhledu se dolaďuje jen jas kvůli kontrastu.
- Událost je zastávka (bílý kroužek na lince). Vícedenní událost je vodorovná linka se zaoblenými konci. Dnešek a aktuální čas jsou přestupní kruh.
- Kategorie nese symbol, ne barva. Kalendář má vedle barvy vždy i název v panelu a v detailu, barva není jediný nosič významu.
- Písmo: systémové (SF Pro), tabulkové číslice, na iPhonu v měsíci zúžený řez. Žádná vlastní písma.
- Ovládací prvky jsou nativní (segmentovaný přepínač, listy, popovery, kontextové nabídky, systémové výběry data a barvy). Svět dodává jen barvy, písmo, hustotu a kresbu linek.
- Pohyb: systémové přechody; přepnutí pohledu prolnutím, při „Omezit pohyb“ bez animace posunu.
- Přístupnost: Dynamic Type, VoiceOver (den jako skupina se seznamem událostí, u události kalendář i kategorie slovně), zvýšený kontrast, minimální dotyková plocha 44 bodů na iOS.

Závazný náčrt první obrazovky: `.impeccable/mocks/decision/challenger-transit.html` (měsíc na Macu). Smlouva o směru je v `.impeccable/surfaces/`.

## 7. Testování

- `DaybookCore` jednotkovými testy: `MonthLayout` (pruhy vícedenních událostí, přechod přes týden a měsíc, řazení, začátek týdne, letní čas), `TimeGridLayout` (překryvy), `VisibilityFilter`, `EventSearch` (diakritika, pole, rozsah), `EventKey` a přiřazení kategorií.
- Aplikace: sestavení pro iOS simulátor a macOS, ruční průchod se snímky obrazovky (iPhone, iPad, Mac; tmavý a světlý vzhled; velké písmo) nad ukázkovými daty z `InMemoryCalendarStore`, která se zapínají spouštěcím argumentem.
- EventKit se v automatických testech nevolá; `EventKitCalendarStore` se ověřuje ručně na zařízení s reálnými účty.

## 8. Mimo první verzi

Widgety, vlastní notifikace, přetahování událostí, zadávání přirozeným jazykem, roční pohled, úkoly a připomínky, pozvánky z macOS, vlastní přihlášení ke Googlu nebo Microsoftu, monetizace.

## 9. Pořadí stavby

1. Základ: projekt, balíček, modely, `CalendarStore`, oprávnění, kostra, postranní panel s vypínáním kalendářů, měsíc.
2. Týden a den.
3. Editor události, mazání, nový kalendář, změna barvy.
4. Kategorie se synchronizací a filtrem.
5. Vyhledávání, lokalizace, přístupnost, závěrečná kontrola vzhledu.

Každý krok končí spustitelnou aplikací.

## 10. Co je potřeba od uživatele

- Placený Apple Developer účet a identifikátor týmu pro CloudKit kontejner a podepisování (krok 4; do té doby aplikace běží bez synchronizace).
- Potvrzení veřejného názvu aplikace a bundle identifikátoru (zatím pracovně `Daybook`).
