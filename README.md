# GlucoPilot

> **🧪 Proof of concept.** Projet personnel exploratoire, publié pour partager
> l'approche technique. Pas de support, pas de garantie de maintenance ni de
> compatibilité ascendante — ce n'est pas un produit fini.
>
> ⚠️ **Avertissement médical.** Outil de **confort** uniquement, ce n'est **pas
> un dispositif médical**. Il s'appuie sur l'API **non officielle** Dexcom
> Share, qui peut tomber, renvoyer des valeurs périmées ou être coupée sans
> préavis. Les alarmes de l'application Dexcom officielle restent la seule
> référence. Ne fondez aucune décision thérapeutique sur cet affichage.

Sa glycémie sur l'écran de la voiture, en un coup d'œil.

App iOS qui lit la glycémie temps réel via l'API **Dexcom Share** et l'affiche
dans **CarPlay** — sans entitlement CarPlay, en s'appuyant sur les surfaces
ouvertes par iOS 26 :

- **Live Activity** (famille d'activité `small`) → affichée en permanence sur le
  Dashboard CarPlay, et en bandeau d'alerte si le Dashboard n'est pas visible.
- **Widget** (`systemSmall`) → page de widgets à gauche du Dashboard CarPlay,
  et réutilisable sur l'écran d'accueil / de verrouillage de l'iPhone.
- **App Intent Siri** → « Dis Siri, ma glycémie », réponse vocale, mains sur le
  volant.

> Apple n'accorde d'entitlement CarPlay qu'à 6 catégories (audio, navigation,
> communication, recharge VE, carburant/parking, driving task). Aucune n'est
> médicale. Mais depuis iOS 26 : *« If your app supports widgets or Live
> Activities, you can make them available to drivers in CarPlay, even if you
> don't have a CarPlay app. »* — WWDC25, *Turbocharge your app for CarPlay*.

## Source des données

L'API **Dexcom Share** (non officielle, temps réel), la même que celle validée
en production sur le projet [veilleuse-dexcom](https://github.com/didux123/veilleuse-dexcom) :
auth en 3 étapes, base régionale US/OUS, mapping des tendances, règle
anti-verrouillage de compte.

L'API officielle `developer.dexcom.com` est écartée : ses données sont retardées
de 3 h hors USA, par exigence réglementaire — inutilisable au volant.

## Mise à jour sans serveur

Tout se passe sur l'iPhone, il n'y a rien à héberger. Trois régimes :

| Situation | Mécanisme | Fraîcheur |
|---|---|---|
| En voiture | Réveil par déplacement significatif, puis localisation continue (3 km de précision — on ne veut pas la position, juste rester vivant) | 60 s |
| App fermée | L'extension widget interroge Dexcom dans sa propre timeline | 20 à 30 min (budget WidgetKit) |
| App ouverte | Boucle de premier plan | 60 s |

Conséquence assumée : si l'app était suspendue au moment où vous branchez le
téléphone, la Live Activity n'apparaît qu'après les premières centaines de
mètres. C'est le prix du zéro-serveur — si ça gêne, la bascule vers un backend
poussant en APNs se fait sans rien changer à l'affichage.

## Construire

```bash
brew install xcodegen && xcodegen generate && open GlucoPilot.xcodeproj
```

Le `.xcodeproj` est généré depuis `project.yml` et n'est pas versionné :
relancez `xcodegen generate` après tout ajout de fichier.

Le **Team ID n'est pas dans le dépôt** (il est propre à la machine) :

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig   # puis renseigner le Team ID
```

Passer par un xcconfig plutôt que par l'interface de Xcode permet au réglage de
survivre à chaque `xcodegen generate`.

Installer sur un iPhone branché :

```bash
xcodebuild -project GlucoPilot.xcodeproj -scheme GlucoPilot -destination "platform=iOS,id=$(xcrun xctrace list devices | grep -m1 -oE '\(([0-9A-F]{8}-[0-9A-F]{16})\)' | tr -d '()')" -allowProvisioningUpdates build
```

puis `xcrun devicectl device install app --device <UDID> <chemin>/GlucoPilot.app`.

Tests de la couche Dexcom :

```bash
cd GlucoKit && swift test
```

Aucun test n'appelle Dexcom pour de vrai — un compte Share se verrouille au
bout de quelques tentatives ratées.

## Mode démo

En Debug, pour regarder à quoi ressemble une hypo à l'écran sans attendre d'en
faire une :

```bash
xcrun simctl launch booted com.didux.glucopilot -demo hypo
```

États : `ok`, `hyper`, `hyperSevere`, `hypo`, `imminentHypo`, `stale`.
`-gallery` affiche les deux surfaces CarPlay dans tous leurs états à la taille
réelle (aussi accessible depuis *Réglages → Aperçu du widget*).

## Statut

Les cinq étapes sont écrites et compilent : couche Dexcom (46 tests), app,
widget, Live Activity, Siri. **Reste la validation en voiture réelle** —
téléphone verrouillé, Live Activity qui démarre seule, mise à jour pendant le
trajet, et relevé de consommation batterie sur une heure.

## Sécurité

Aucun identifiant Dexcom dans le dépôt ni dans le binaire. Les identifiants sont
saisis par l'utilisateur et stockés dans le **Trousseau iOS**.

## Avertissement

GlucoPilot n'est pas un dispositif médical. Ne jamais prendre de décision de
traitement sur la base de cet affichage : se référer à l'application Dexcom
officielle et à un contrôle capillaire.

## Licence

MIT
