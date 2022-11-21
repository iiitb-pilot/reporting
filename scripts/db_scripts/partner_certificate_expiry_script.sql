CREATE MATERIALIZED VIEW mv_partner_certificate_expiry AS SELECT P.ISSUER_ID, SPLIT_PART(SPLIT_PART(P.CERT_SUBJECT, ',', 1),'=',2) AS COMMON_NAME, P.ORGANIZATION_NAME, P.PARTNER_DOMAIN, TO_CHAR(P.CERT_NOT_AFTER, 'DD/MON/YYYY') AS PARTNER_EXPIRY_ON,
CASE WHEN CA.CA2_EXPIRY_ON IS NOT NULL THEN CA.CA1_EXPIRY_ON ELSE NULL END AS INTER_EXPIRY_ON,
CASE WHEN CA.CA2_EXPIRY_ON IS NOT NULL THEN CA.CA2_EXPIRY_ON ELSE CA.CA1_EXPIRY_ON END AS CA_EXPIRY_ON,
CA3.MOSIP_EXPIRY_ON
FROM keymgr.partner_cert_store P
LEFT JOIN (
SELECT CA1.CERT_ID, TO_CHAR(CA1.CERT_NOT_AFTER, 'DD/MON/YYYY') AS CA1_EXPIRY_ON, TO_CHAR(CA2.CERT_NOT_AFTER, 'DD/MON/YYYY') AS CA2_EXPIRY_ON FROM  keymgr.ca_cert_store CA1
LEFT JOIN keymgr.ca_cert_store CA2 ON CA2.CERT_ID = CA1.ISSUER_ID AND CA1.CERT_ID != CA1.ISSUER_ID
) CA ON CA.CERT_ID = P.ISSUER_ID
LEFT JOIN (SELECT CERT_SUBJECT, CERT_ISSUER, TO_CHAR(MAX(CERT_NOT_AFTER), 'DD/MON/YYYY') AS MOSIP_EXPIRY_ON FROM keymgr.ca_cert_store GROUP BY CERT_SUBJECT, CERT_ISSUER) CA3 ON CA3.CERT_SUBJECT = P.CERT_SUBJECT AND CA3.CERT_ISSUER LIKE '%MOSIP-TECH-CENTER (PMS)%';
create or replace function mv_partner_certificate_expiry_trigger()
returns trigger SECURITY DEFINER
as $$
begin
    refresh materialized view mv_partner_certificate_expiry;
    RETURN NULL;
end $$ language plpgsql;
create trigger ca_cert_store_trigger after insert or update or delete or truncate on ca_cert_store for each statement execute procedure mv_partner_certificate_expiry_trigger();
create trigger partner_cert_store_view after insert or update or delete or truncate on partner_cert_store for each statement execute procedure mv_partner_certificate_expiry_trigger();