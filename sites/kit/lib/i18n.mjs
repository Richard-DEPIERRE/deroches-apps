/** Interface words, per language. Page text lives in content/<lang>/; only the kit's own words live here. */
export const STRINGS = {
  fr: {
    locale: 'fr_FR',
    languageName: 'Français',
    skip: 'Aller au contenu',
    home: 'Accueil',
    otherLanguage: 'Lire en français',
    language: 'Langue',
    footer: 'Aide et informations légales',
    notFoundTitle: 'Page introuvable',
    notFoundText: 'Cette page n’existe pas ou a été déplacée.',
    backHome: 'Retour à l’accueil',
    comingSoon: 'Bientôt sur l’App Store et Google Play.',
    firstGuides: 'Premiers guides',
    lastUpdated: 'Dernière mise à jour :',
    published: 'Publié le',
    updated: 'mis à jour le',
    breadcrumb: 'Fil d’Ariane',
    guides: 'Guides',
    // No article or preposition touches the name ("de Exemple"); a no-break space before the colon.
    guidesDescription: (name) => `${name}\u00a0: tous les guides, du plus récent au plus ancien.`,
    sources: 'Sources',
    read: 'consulté le',
    stores: { ios: 'Télécharger sur l’App Store', android: 'Télécharger sur Google Play' },
    replyWithinWorkingDay: 'Nous répondons à chaque e-mail sous un jour ouvré.',
    identityMissing:
      'Fichier d’identité manquant : les informations sur l’éditeur et l’hébergeur seront ajoutées avant la mise en ligne.',
    publisher: 'Éditeur du site',
    host: 'Hébergeur',
    name: 'Nom',
    legalForm: 'Forme juridique',
    shareCapital: 'Capital social',
    address: 'Adresse',
    email: 'E-mail',
    phone: 'Téléphone',
    registration: 'Immatriculation',
    vatNumber: 'Numéro de TVA intracommunautaire',
    publicationDirector: 'Directeur de la publication',
  },
  en: {
    locale: 'en_GB',
    languageName: 'English',
    skip: 'Skip to content',
    home: 'Home',
    otherLanguage: 'Read in English',
    language: 'Language',
    footer: 'Help and legal information',
    notFoundTitle: 'Page not found',
    notFoundText: 'This page doesn’t exist or has moved.',
    backHome: 'Back to the home page',
    comingSoon: 'Coming soon to the App Store and Google Play.',
    firstGuides: 'First guides',
    lastUpdated: 'Last updated:',
    published: 'Published',
    updated: 'updated',
    breadcrumb: 'Breadcrumb',
    guides: 'Guides',
    guidesDescription: (name) => `Every ${name} guide, newest first.`,
    sources: 'Sources',
    read: 'checked',
    stores: { ios: 'Download from the App Store', android: 'Download from Google Play' },
    replyWithinWorkingDay: 'We answer every email within a working day.',
    identityMissing:
      'Identity file missing: the publisher and host details will be added before the site goes live.',
    publisher: 'Publisher',
    host: 'Host',
    name: 'Name',
    legalForm: 'Legal form',
    shareCapital: 'Share capital',
    address: 'Address',
    email: 'Email',
    phone: 'Phone',
    registration: 'Registration',
    vatNumber: 'EU VAT number',
    publicationDirector: 'Publication director',
  },
};

/** A YYYY-MM-DD date in words, in the page language ("6 novembre 2026", "6 November 2026"). */
export function longDate(lang, iso) {
  const format = new Intl.DateTimeFormat(STRINGS[lang].locale.replace('_', '-'), {
    dateStyle: 'long',
    timeZone: 'UTC',
  });
  const text = format.format(new Date(`${iso}T00:00:00Z`));
  // French writes the first of the month as an ordinal: "1er novembre 2026".
  return lang === 'fr' ? text.replace(/^1 /, '1er ') : text;
}
