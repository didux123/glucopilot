# GlucoPilot

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

## Statut

Recherche de faisabilité terminée. Plan d'implémentation en cours.

## Sécurité

Aucun identifiant Dexcom dans le dépôt ni dans le binaire. Les identifiants sont
saisis par l'utilisateur et stockés dans le **Trousseau iOS**.

## Avertissement

GlucoPilot n'est pas un dispositif médical. Ne jamais prendre de décision de
traitement sur la base de cet affichage : se référer à l'application Dexcom
officielle et à un contrôle capillaire.

## Licence

MIT
