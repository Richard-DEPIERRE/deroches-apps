# Legal identity (Richard's file)

The legal notice ("mentions légales") of every site includes `sites/legal/identity.json`. **Richard writes and merges
it himself**; agents never create, fill or edit it, and never copy its values anywhere else. The kit only reads it.

Fields (names only; French legal-notice requirements, entreprendre.service-public.gouv.fr/vosdroits/F37351, checked
2026-11-01):

| Field | What goes in it |
|---|---|
| `publisher.name` | the publisher's name or company name, with "EI" for an individual entrepreneur |
| `publisher.legalForm` | the legal form (EI, SASU, SARL…) |
| `publisher.shareCapital` | share capital, for a company only (else leave it out) |
| `publisher.address` | registered office or domiciliation address |
| `publisher.email` | contact email |
| `publisher.phone` | contact phone |
| `publisher.registration` | RCS and/or RNE registration, as it should be printed |
| `publisher.vatNumber` | intra-EU VAT number, only where one applies (else leave it out) |
| `publicationDirector` | the publication director's name |
| `host.name`, `host.address`, `host.phone` | the host's name, address and phone |

Until the file exists, a site can be built for review but not deployed: the legal notice must carry it.
