-- Analyse et application, en plus de la provenance.
--
-- `context` répond à « d'où ça vient » : c'est un fait, il se vérifie ou ne s'écrit pas,
-- et il restera donc absent sur la majorité des citations. `meaning` et `application`
-- répondent à « qu'est-ce que ça veut dire » et « qu'est-ce que j'en fais » : ce sont des
-- lectures du texte lui-même, pas des affirmations sur le passé. Elles peuvent donc être
-- rédigées pour toutes les citations, y compris celles dont l'origine est introuvable.
--
-- C'est cette distinction qui permet de passer de 12 % de fiches renseignées à la quasi
-- totalité sans inventer une seule source.

alter table public.quotes
  add column if not exists meaning text,
  add column if not exists application text;
