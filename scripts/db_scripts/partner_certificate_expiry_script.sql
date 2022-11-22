--CREATE MATERIALIZED VIEW mv_partner_certificate_expiry AS SELECT P.ISSUER_ID, SPLIT_PART(SPLIT_PART(P.CERT_SUBJECT, ',', 1),'=',2) AS COMMON_NAME, P.ORGANIZATION_NAME, P.PARTNER_DOMAIN, TO_CHAR(P.CERT_NOT_AFTER, 'DD/MON/YYYY') AS PARTNER_EXPIRY_ON,
--CASE WHEN CA.CA2_EXPIRY_ON IS NOT NULL THEN CA.CA1_EXPIRY_ON ELSE NULL END AS INTER_EXPIRY_ON,
--CASE WHEN CA.CA2_EXPIRY_ON IS NOT NULL THEN CA.CA2_EXPIRY_ON ELSE CA.CA1_EXPIRY_ON END AS CA_EXPIRY_ON,
--CA3.MOSIP_EXPIRY_ON
--FROM keymgr.partner_cert_store P
--LEFT JOIN (
--SELECT CA1.CERT_ID, TO_CHAR(CA1.CERT_NOT_AFTER, 'DD/MON/YYYY') AS CA1_EXPIRY_ON, TO_CHAR(CA2.CERT_NOT_AFTER, 'DD/MON/YYYY') AS CA2_EXPIRY_ON FROM  keymgr.ca_cert_store CA1
--LEFT JOIN keymgr.ca_cert_store CA2 ON CA2.CERT_ID = CA1.ISSUER_ID AND CA1.CERT_ID != CA1.ISSUER_ID
--) CA ON CA.CERT_ID = P.ISSUER_ID
--LEFT JOIN (SELECT CERT_SUBJECT, CERT_ISSUER, TO_CHAR(MAX(CERT_NOT_AFTER), 'DD/MON/YYYY') AS MOSIP_EXPIRY_ON FROM keymgr.ca_cert_store GROUP BY CERT_SUBJECT, CERT_ISSUER) CA3 ON CA3.CERT_SUBJECT = P.CERT_SUBJECT AND CA3.CERT_ISSUER LIKE '%MOSIP-TECH-CENTER (PMS)%';
CREATE TABLE PARTNER_CERTIFICATE_EXPIRY (
ISSUER_ID VARCHAR(36) PRIMARY KEY,
COMMON_NAME VARCHAR(200) NOT NULL,
ORGANIZATION_NAME VARCHAR(128) NOT NULL,
PARTNER_DOMAIN VARCHAR(36) NOT NULL,
PARTNER_EXPIRY_ON timestamp,
INTER_EXPIRY_ON timestamp,
CA_EXPIRY_ON timestamp,
MOSIP_EXPIRY_ON timestamp
);

create or replace function partner_certificate_expiry_trigger()
returns trigger SECURITY DEFINER
as $$
begin
    TRUNCATE TABLE PARTNER_CERTIFICATE_EXPIRY;
    INSERT INTO PARTNER_CERTIFICATE_EXPIRY (SELECT P.ISSUER_ID, SPLIT_PART(SPLIT_PART(P.CERT_SUBJECT, ',', 1),'=',2) AS COMMON_NAME, P.ORGANIZATION_NAME, P.PARTNER_DOMAIN, P.CERT_NOT_AFTER AS PARTNER_EXPIRY_ON,
                                            CASE WHEN CA.CA2_EXPIRY_ON IS NOT NULL THEN CA.CA1_EXPIRY_ON ELSE NULL END AS INTER_EXPIRY_ON,
                                            CASE WHEN CA.CA2_EXPIRY_ON IS NOT NULL THEN CA.CA2_EXPIRY_ON ELSE CA.CA1_EXPIRY_ON END AS CA_EXPIRY_ON,
                                            CA3.MOSIP_EXPIRY_ON
                                            FROM keymgr.partner_cert_store P
                                            LEFT JOIN (
                                            SELECT CA1.CERT_ID, CA1.CERT_NOT_AFTER AS CA1_EXPIRY_ON, CA2.CERT_NOT_AFTER AS CA2_EXPIRY_ON FROM  keymgr.ca_cert_store CA1
                                            LEFT JOIN keymgr.ca_cert_store CA2 ON CA2.CERT_ID = CA1.ISSUER_ID AND CA1.CERT_ID != CA1.ISSUER_ID
                                            ) CA ON CA.CERT_ID = P.ISSUER_ID
                                            LEFT JOIN (SELECT CERT_SUBJECT, CERT_ISSUER, MAX(CERT_NOT_AFTER) AS MOSIP_EXPIRY_ON FROM keymgr.ca_cert_store GROUP BY CERT_SUBJECT, CERT_ISSUER) CA3 ON CA3.CERT_SUBJECT = P.CERT_SUBJECT AND CA3.CERT_ISSUER LIKE '%MOSIP-TECH-CENTER (PMS)%');
                                            RETURN NULL;
end $$ language plpgsql;
create trigger ca_cert_store_trigger after insert or update or delete or truncate on ca_cert_store for each statement execute procedure partner_certificate_expiry_trigger();
create trigger partner_cert_store_view after insert or update or delete or truncate on partner_cert_store for each statement execute procedure partner_certificate_expiry_trigger();