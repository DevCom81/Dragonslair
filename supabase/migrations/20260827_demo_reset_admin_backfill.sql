-- Passe 1 : remettre en demo les licences FULL accordees automatiquement
-- (source = admin) pour que l'offre Demo / Acheter s'affiche.
-- Ne touche pas aux achats Stripe (source = purchase).
-- Executer manuellement. Ne pas ecraser supabase/schema.sql.

update user_entitlements
set access_level = 'demo',
    source = 'default'
where access_level = 'full'
  and source = 'admin';
