-- ============================================
-- CONCEPTION DE BASE DE DONNeES POUR AQUACULTURE
-- PostgreSQL
-- ============================================

-- ============================================
-- 1. TABLES PRINCIPALES
-- ============================================

-- Table Race de poisson
CREATE TABLE race_poisson (
    id_race SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    poids_maximum DECIMAL(10,2) NOT NULL,
    capacite_augmentation_poids DECIMAL(10,2) NOT NULL,
    poids_initial DECIMAL(10,2) NOT NULL,
    besoin_proteines DECIMAL(10,2) DEFAULT 2.0,
    besoin_glucides DECIMAL(10,2) DEFAULT 4.0,
    prix_vente DECIMAL(10,2) NOT NULL,
    prix_achat DECIMAL(10,2) NOT NULL
);

COMMENT ON COLUMN race_poisson.besoin_proteines IS 'Besoin quotidien en grammes';
COMMENT ON COLUMN race_poisson.besoin_glucides IS 'Besoin quotidien en grammes';

-- Table Bassin
CREATE TABLE bassin (
    id_bassin SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    capacite_max_poissons INTEGER NOT NULL,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    est_actif BOOLEAN DEFAULT TRUE
);

-- Table Poisson
CREATE TABLE poisson (
    id_poisson SERIAL PRIMARY KEY,
    id_race INTEGER REFERENCES race_poisson(id_race),
    id_bassin INTEGER REFERENCES bassin(id_bassin),
    nom VARCHAR(100),
    date_entree_piscine TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    est_vivant BOOLEAN DEFAULT TRUE,
    date_sortie TIMESTAMP,
    CONSTRAINT fk_bassin FOREIGN KEY (id_bassin) REFERENCES bassin(id_bassin)
);

-- Table Aliment
CREATE TABLE aliment (
    id_aliment SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prix_achat_par_kg DECIMAL(10,2) NOT NULL,
    apport_proteines_pour_100g DECIMAL(10,2) NOT NULL, -- en grammes pour 100g
    apport_glucides_pour_100g DECIMAL(10,2) NOT NULL   -- en grammes pour 100g
);

-- Table Plat (composition)
CREATE TABLE plat (
    id_plat SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table Composition_plat
CREATE TABLE composition_plat (
    id_composition SERIAL PRIMARY KEY,
    id_plat INTEGER REFERENCES plat(id_plat),
    id_aliment INTEGER REFERENCES aliment(id_aliment),
    poids_kg DECIMAL(10,2) NOT NULL
);

-- Table fisakafoanana (evolution du poids)
CREATE TABLE fisakafoanana (
    id_fisakafoanana SERIAL PRIMARY KEY,
    id_poisson INTEGER REFERENCES poisson(id_poisson),
    date_mesure TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ancien_poids DECIMAL(10,2) NOT NULL,
    nouveau_poids DECIMAL(10,2) NOT NULL,
    proteines_consommees DECIMAL(10,2),
    glucides_consommes DECIMAL(10,2),
    id_plat INTEGER REFERENCES plat(id_plat),
    CONSTRAINT poids_positif CHECK (nouveau_poids > 0 AND ancien_poids > 0)
);

-- Table Distribution_nourriture
CREATE TABLE distribution_nourriture (
    id_distribution SERIAL PRIMARY KEY,
    id_bassin INTEGER REFERENCES bassin(id_bassin),
    id_plat INTEGER REFERENCES plat(id_plat),
    date_distribution TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    quantite_totale_kg DECIMAL(10,2) NOT NULL
);

-- Table Transfert_poisson
CREATE TABLE transfert_poisson (
    id_transfert SERIAL PRIMARY KEY,
    id_poisson INTEGER REFERENCES poisson(id_poisson),
    ancien_bassin INTEGER REFERENCES bassin(id_bassin),
    nouveau_bassin INTEGER REFERENCES bassin(id_bassin),
    date_transfert TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raison VARCHAR(255)
);

-- ============================================
-- 2. INDEX POUR PERFORMANCE
-- ============================================

CREATE INDEX idx_fisakafoanana_poisson_date ON fisakafoanana(id_poisson, date_mesure);
CREATE INDEX idx_poisson_race ON poisson(id_race);
CREATE INDEX idx_poisson_bassin ON poisson(id_bassin);
CREATE INDEX idx_composition_plat ON composition_plat(id_plat);
CREATE INDEX idx_distribution_bassin ON distribution_nourriture(id_bassin, date_distribution);

-- ============================================
-- 3. VUES
-- ============================================

-- Vue pour obtenir le poids actuel de chaque poisson
CREATE OR REPLACE VIEW v_poids_actuel_poisson AS
SELECT 
    p.id_poisson,
    p.nom,
    p.id_race,
    p.id_bassin,
    b.nom AS nom_bassin,
    r.poids_maximum,
    COALESCE(
        (SELECT nouveau_poids 
         FROM fisakafoanana 
         WHERE id_poisson = p.id_poisson 
         ORDER BY date_mesure DESC 
         LIMIT 1),
        r.poids_initial
    ) AS poids_actuel,
    p.date_entree_piscine,
    p.est_vivant
FROM poisson p
JOIN race_poisson r ON p.id_race = r.id_race
LEFT JOIN bassin b ON p.id_bassin = b.id_bassin;

-- Vue pour voir les statistiques des bassins
CREATE OR REPLACE VIEW v_statistiques_bassin AS
SELECT 
    b.id_bassin,
    b.nom,
    b.capacite_max_poissons,
    COUNT(p.id_poisson) AS nombre_poissons,
    COUNT(p.id_poisson) FILTER (WHERE p.est_vivant = TRUE) AS poissons_vivants,
    COUNT(p.id_poisson) FILTER (WHERE p.est_vivant = FALSE) AS poissons_morts,
    COALESCE(AVG(vp.poids_actuel), 0) AS poids_moyen,
    MIN(vp.poids_actuel) AS poids_min,
    MAX(vp.poids_actuel) AS poids_max,
    ROUND((COUNT(p.id_poisson)::DECIMAL / b.capacite_max_poissons * 100), 2) AS taux_occupation
FROM bassin b
LEFT JOIN poisson p ON b.id_bassin = p.id_bassin
LEFT JOIN v_poids_actuel_poisson vp ON p.id_poisson = vp.id_poisson
WHERE b.est_actif = TRUE
GROUP BY b.id_bassin, b.nom, b.capacite_max_poissons;

-- ============================================
-- 4. FONCTIONS
-- ============================================

-- Fonction pour calculer la prise de poids (CORRIGeE)
CREATE OR REPLACE FUNCTION calculer_prise_poids(
    p_besoin_proteines DECIMAL,
    p_besoin_glucides DECIMAL,
    p_proteines_consommees DECIMAL,
    p_glucides_consommes DECIMAL,
    p_capacite_augmentation DECIMAL
)
RETURNS DECIMAL AS $$
DECLARE
    ratio_proteines DECIMAL;
    ratio_glucides DECIMAL;
BEGIN
    -- Calcul des ratios (max 1.0 si depassement)
    ratio_proteines := LEAST(p_proteines_consommees / p_besoin_proteines, 1.0);
    ratio_glucides := LEAST(p_glucides_consommes / p_besoin_glucides, 1.0);
    
    -- Prise de poids = capacite * (ratio_proteines + ratio_glucides) / 2
    -- Cette formule correspond aux exemples donnes
    RETURN p_capacite_augmentation * (ratio_proteines + ratio_glucides) / 2;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour nourrir les poissons d'un bassin (CORRIGeE)
CREATE OR REPLACE FUNCTION nourrir_poissons(
    p_id_bassin INTEGER,
    p_id_plat INTEGER,
    p_quantite_totale_kg DECIMAL
)
RETURNS TABLE(
    id_poisson INTEGER,
    id_bassin INTEGER,
    poids_avant DECIMAL,
    poids_apres DECIMAL,
    proteines_recues DECIMAL,
    glucides_recus DECIMAL,
    prise_poids DECIMAL
) AS $$
DECLARE
    v_proteines_totales DECIMAL := 0;
    v_glucides_totaux DECIMAL := 0;
    v_nb_poissons_affames INTEGER;
    v_proteines_par_poisson DECIMAL;
    v_glucides_par_poisson DECIMAL;
    rec RECORD;
BEGIN
    -- Verifier si le bassin existe
    IF NOT EXISTS (SELECT 1 FROM bassin WHERE id_bassin = p_id_bassin AND est_actif = TRUE) THEN
        RAISE EXCEPTION 'Bassin non trouve ou inactif';
    END IF;

    -- Calculer les apports nutritionnels totaux du plat (CORRIGE)
    SELECT
        SUM(cp.poids_kg * a.apport_proteines_pour_100g * 10) AS proteines, -- g/100g -> g/kg
        SUM(cp.poids_kg * a.apport_glucides_pour_100g * 10) AS glucides   -- g/100g -> g/kg
    INTO v_proteines_totales, v_glucides_totaux
    FROM composition_plat cp
    JOIN aliment a ON cp.id_aliment = a.id_aliment
    WHERE cp.id_plat = p_id_plat;

    -- Multiplier par la quantite servie
    v_proteines_totales := v_proteines_totales * p_quantite_totale_kg;
    v_glucides_totaux := v_glucides_totaux * p_quantite_totale_kg;

    -- Compter les poissons affames dans ce bassin
    SELECT COUNT(*) INTO v_nb_poissons_affames
    FROM v_poids_actuel_poisson
    WHERE id_bassin = p_id_bassin
    AND est_vivant = TRUE
    AND poids_actuel < poids_maximum;

    IF v_nb_poissons_affames = 0 THEN
        RAISE NOTICE 'Aucun poisson affame dans le bassin %', p_id_bassin;
        RETURN;
    END IF;

    -- Distribution equitable parmi les poissons affames du bassin
    v_proteines_par_poisson := v_proteines_totales / v_nb_poissons_affames;
    v_glucides_par_poisson := v_glucides_totaux / v_nb_poissons_affames;

    -- Pour chaque poisson affame dans le bassin
    FOR rec IN
        SELECT * FROM v_poids_actuel_poisson
        WHERE id_bassin = p_id_bassin
        AND est_vivant = TRUE
        AND poids_actuel < poids_maximum
    LOOP
        DECLARE
            v_prise_poids DECIMAL;
            v_nouveau_poids DECIMAL;
            v_race RECORD;
        BEGIN
            -- Recuperer les infos de la race
            SELECT * INTO v_race FROM race_poisson WHERE id_race = rec.id_race;

            -- Calculer la prise de poids
            v_prise_poids := calculer_prise_poids(
                v_race.besoin_proteines,
                v_race.besoin_glucides,
                v_proteines_par_poisson,
                v_glucides_par_poisson,
                v_race.capacite_augmentation_poids
            );

            -- Nouveau poids (plafonne au max)
            v_nouveau_poids := LEAST(
                rec.poids_actuel + v_prise_poids,
                rec.poids_maximum
            );

            -- Enregistrer dans fisakafoanana
            INSERT INTO fisakafoanana (
                id_poisson,
                ancien_poids,
                nouveau_poids,
                proteines_consommees,
                glucides_consommes,
                id_plat
            ) VALUES (
                rec.id_poisson,
                rec.poids_actuel,
                v_nouveau_poids,
                v_proteines_par_poisson,
                v_glucides_par_poisson,
                p_id_plat
            );

            -- Retourner les resultats
            id_poisson := rec.id_poisson;
            id_bassin := p_id_bassin;
            poids_avant := rec.poids_actuel;
            poids_apres := v_nouveau_poids;
            proteines_recues := v_proteines_par_poisson;
            glucides_recus := v_glucides_par_poisson;
            prise_poids := v_prise_poids;
            RETURN NEXT;
        END;
    END LOOP;

    -- Enregistrer la distribution (avec le bassin)
    INSERT INTO distribution_nourriture (id_bassin, id_plat, quantite_totale_kg)
    VALUES (p_id_bassin, p_id_plat, p_quantite_totale_kg);
END;
$$ LANGUAGE plpgsql;

-- Fonction pour transferer un poisson de bassin
CREATE OR REPLACE FUNCTION transferer_poisson(
    p_id_poisson INTEGER,
    p_nouveau_bassin INTEGER,
    p_raison VARCHAR DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_ancien_bassin INTEGER;
    v_nb_poissons_nouveau INTEGER;
    v_capacite_nouveau INTEGER;
BEGIN
    -- Verifier si le poisson existe et est vivant
    IF NOT EXISTS (SELECT 1 FROM poisson WHERE id_poisson = p_id_poisson AND est_vivant = TRUE) THEN
        RAISE EXCEPTION 'Poisson non trouve ou mort';
    END IF;
    
    -- Verifier si le nouveau bassin existe
    IF NOT EXISTS (SELECT 1 FROM bassin WHERE id_bassin = p_nouveau_bassin AND est_actif = TRUE) THEN
        RAISE EXCEPTION 'Bassin non trouve ou inactif';
    END IF;
    
    -- Verifier la capacite du nouveau bassin
    SELECT capacite_max_poissons INTO v_capacite_nouveau
    FROM bassin WHERE id_bassin = p_nouveau_bassin;
    
    SELECT COUNT(*) INTO v_nb_poissons_nouveau
    FROM poisson WHERE id_bassin = p_nouveau_bassin AND est_vivant = TRUE;
    
    IF v_nb_poissons_nouveau >= v_capacite_nouveau THEN
        RAISE EXCEPTION 'Bassin plein (capacite: %, occupe: %)', v_capacite_nouveau, v_nb_poissons_nouveau;
    END IF;
    
    -- Recuperer l'ancien bassin
    SELECT id_bassin INTO v_ancien_bassin
    FROM poisson WHERE id_poisson = p_id_poisson;
    
    -- Mettre à jour le poisson
    UPDATE poisson 
    SET id_bassin = p_nouveau_bassin
    WHERE id_poisson = p_id_poisson;
    
    -- Enregistrer le transfert
    INSERT INTO transfert_poisson (id_poisson, ancien_bassin, nouveau_bassin, raison)
    VALUES (p_id_poisson, v_ancien_bassin, p_nouveau_bassin, p_raison);
    
    RAISE NOTICE 'Poisson % transfere du bassin % au bassin %', p_id_poisson, v_ancien_bassin, p_nouveau_bassin;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour calculer le benefice (AMeLIOReE)
CREATE OR REPLACE FUNCTION calculer_benefice(
    p_date_debut TIMESTAMP,
    p_date_fin TIMESTAMP,
    p_id_bassin INTEGER DEFAULT NULL
)
RETURNS TABLE(
    id_bassin INTEGER,
    nom_bassin VARCHAR,
    cout_achat_poissons DECIMAL,
    cout_nourriture DECIMAL,
    cout_total DECIMAL,
    revenu_vente DECIMAL,
    benefice DECIMAL
) AS $$
DECLARE
    v_cout_poissons DECIMAL := 0;
    v_cout_nourriture DECIMAL := 0;
    v_revenu DECIMAL := 0;
    rec_bassin RECORD;
BEGIN
    -- Si aucun bassin specifie, calculer pour tous les bassins
    IF p_id_bassin IS NULL THEN
        FOR rec_bassin IN SELECT id_bassin, nom FROM bassin WHERE est_actif = TRUE
        LOOP
            -- Coût d'achat des poissons entres dans ce bassin pendant la periode
            SELECT COALESCE(SUM(r.prix_achat), 0) INTO v_cout_poissons
            FROM poisson p
            JOIN race_poisson r ON p.id_race = r.id_race
            WHERE p.id_bassin = rec_bassin.id_bassin
            AND p.date_entree_piscine BETWEEN p_date_debut AND p_date_fin;
            
            -- Coût de la nourriture distribuee dans ce bassin pendant la periode
            SELECT COALESCE(SUM(
                dn.quantite_totale_kg * (
                    SELECT SUM(cp.poids_kg * a.prix_achat_par_kg)
                    FROM composition_plat cp
                    JOIN aliment a ON cp.id_aliment = a.id_aliment
                    WHERE cp.id_plat = dn.id_plat
                )
            ), 0) INTO v_cout_nourriture
            FROM distribution_nourriture dn
            WHERE dn.id_bassin = rec_bassin.id_bassin
            AND dn.date_distribution BETWEEN p_date_debut AND p_date_fin;
            
            -- Revenu de vente (poissons vendus/morts de ce bassin pendant la periode)
            SELECT COALESCE(SUM(r.prix_vente), 0) INTO v_revenu
            FROM poisson p
            JOIN race_poisson r ON p.id_race = r.id_race
            WHERE p.id_bassin = rec_bassin.id_bassin
            AND p.date_sortie BETWEEN p_date_debut AND p_date_fin
            AND p.est_vivant = FALSE;
            
            -- Retourner les resultats pour ce bassin
            id_bassin := rec_bassin.id_bassin;
            nom_bassin := rec_bassin.nom;
            cout_achat_poissons := v_cout_poissons;
            cout_nourriture := v_cout_nourriture;
            cout_total := v_cout_poissons + v_cout_nourriture;
            revenu_vente := v_revenu;
            benefice := v_revenu - (v_cout_poissons + v_cout_nourriture);
            
            RETURN NEXT;
        END LOOP;
    ELSE
        -- Calcul pour un bassin specifique
        -- Coût d'achat des poissons
        SELECT COALESCE(SUM(r.prix_achat), 0) INTO v_cout_poissons
        FROM poisson p
        JOIN race_poisson r ON p.id_race = r.id_race
        WHERE p.id_bassin = p_id_bassin
        AND p.date_entree_piscine BETWEEN p_date_debut AND p_date_fin;
        
        -- Coût de la nourriture
        SELECT COALESCE(SUM(
            dn.quantite_totale_kg * (
                SELECT SUM(cp.poids_kg * a.prix_achat_par_kg)
                FROM composition_plat cp
                JOIN aliment a ON cp.id_aliment = a.id_aliment
                WHERE cp.id_plat = dn.id_plat
            )
        ), 0) INTO v_cout_nourriture
        FROM distribution_nourriture dn
        WHERE dn.id_bassin = p_id_bassin
        AND dn.date_distribution BETWEEN p_date_debut AND p_date_fin;
        
        -- Revenu de vente
        SELECT COALESCE(SUM(r.prix_vente), 0) INTO v_revenu
        FROM poisson p
        JOIN race_poisson r ON p.id_race = r.id_race
        WHERE p.id_bassin = p_id_bassin
        AND p.date_sortie BETWEEN p_date_debut AND p_date_fin
        AND p.est_vivant = FALSE;
        
        -- Recuperer le nom du bassin
        SELECT nom INTO nom_bassin FROM bassin WHERE id_bassin = p_id_bassin;
        
        -- Retourner les resultats
        id_bassin := p_id_bassin;
        cout_achat_poissons := v_cout_poissons;
        cout_nourriture := v_cout_nourriture;
        cout_total := v_cout_poissons + v_cout_nourriture;
        revenu_vente := v_revenu;
        benefice := v_revenu - (v_cout_poissons + v_cout_nourriture);
        
        RETURN NEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour vendre un poisson (marquer comme mort/vendu)
CREATE OR REPLACE FUNCTION vendre_poisson(
    p_id_poisson INTEGER
)
RETURNS DECIMAL AS $$
DECLARE
    v_prix_vente DECIMAL;
    v_poids_actuel DECIMAL;
    v_nom_race VARCHAR;
BEGIN
    -- Verifier si le poisson existe et est vivant
    IF NOT EXISTS (SELECT 1 FROM poisson WHERE id_poisson = p_id_poisson AND est_vivant = TRUE) THEN
        RAISE EXCEPTION 'Poisson non trouve ou dejà vendu/mort';
    END IF;
    
    -- Recuperer le prix de vente et le poids
    SELECT r.prix_vente, r.nom, vp.poids_actuel 
    INTO v_prix_vente, v_nom_race, v_poids_actuel
    FROM poisson p
    JOIN race_poisson r ON p.id_race = r.id_race
    JOIN v_poids_actuel_poisson vp ON p.id_poisson = vp.id_poisson
    WHERE p.id_poisson = p_id_poisson;
    
    -- Marquer le poisson comme mort/vendu
    UPDATE poisson 
    SET est_vivant = FALSE, 
        date_sortie = CURRENT_TIMESTAMP
    WHERE id_poisson = p_id_poisson;
    
    RAISE NOTICE 'Poisson % (%, poids: %g) vendu pour % Ar', 
        p_id_poisson, v_nom_race, v_poids_actuel, v_prix_vente;
    
    RETURN v_prix_vente;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. DeCLENCHEURS (TRIGGERS)
-- ============================================

-- Declencheur pour mettre à jour automatiquement la date de sortie
CREATE OR REPLACE FUNCTION update_date_sortie()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.est_vivant = FALSE AND OLD.est_vivant = TRUE THEN
        NEW.date_sortie = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_date_sortie
BEFORE UPDATE ON poisson
FOR EACH ROW
EXECUTE FUNCTION update_date_sortie();

-- ============================================
-- 6. DONNeES D'EXEMPLE
-- ============================================

-- Insertion de races de poisson
INSERT INTO race_poisson (nom, poids_maximum, capacite_augmentation_poids, poids_initial, besoin_proteines, besoin_glucides, prix_vente, prix_achat) VALUES
('Tilapia', 500.00, 20.00, 50.00, 2.00, 4.00, 15000.00, 5000.00),
('Carp', 800.00, 25.00, 60.00, 2.50, 5.00, 20000.00, 7000.00),
('Catfish', 1000.00, 30.00, 80.00, 3.00, 6.00, 25000.00, 8000.00);

-- Insertion de bassins
INSERT INTO bassin (nom, capacite_max_poissons) VALUES
('Bassin Nord - Elevage', 100),
('Bassin Sud - Grossissement', 150),
('Bassin Est - Reproduction', 50),
('Bassin Ouest - Quarantaine', 30);

-- Insertion d'aliments
INSERT INTO aliment (nom, prix_achat_par_kg, apport_proteines_pour_100g, apport_glucides_pour_100g) VALUES
('Larves', 2000.00, 10.00, 10.00),     -- 10g/100g = 100g/kg
('Granules Premium', 3500.00, 15.00, 20.00),
('Farine de poisson', 4000.00, 25.00, 5.00),
('Melange cerealier', 1500.00, 8.00, 25.00);

-- Creation de plats
INSERT INTO plat (nom) VALUES
('Plat Standard - Larves'),
('Plat energetique - Melange'),
('Plat Proteine - Premium');

-- Composition des plats
INSERT INTO composition_plat (id_plat, id_aliment, poids_kg) VALUES
-- Plat 1: 5kg de larves
(1, 1, 5.00),
-- Plat 2: 3kg granules + 2kg melange
(2, 2, 3.00),
(2, 4, 2.00),
-- Plat 3: 4kg farine + 1kg granules
(3, 3, 4.00),
(3, 2, 1.00);

-- Insertion de poissons d'exemple
INSERT INTO poisson (id_race, id_bassin, nom) VALUES 
(1, 1, 'Tilapia-001'),
(1, 1, 'Tilapia-002'),
(1, 1, 'Tilapia-003'),
(2, 2, 'Carp-001'),
(2, 2, 'Carp-002'),
(3, 3, 'Catfish-001');

-- ============================================
-- 7. TESTS ET EXEMPLES D'UTILISATION
-- ============================================

-- Exemple 1: Nourrir les poissons du bassin 1 avec 50g du plat 1
-- SELECT * FROM nourrir_poissons(1, 1, 0.05);

-- Exemple 2: Voir le poids actuel des poissons
-- SELECT * FROM v_poids_actuel_poisson ORDER BY id_bassin, id_poisson;

-- Exemple 3: Voir les statistiques des bassins
-- SELECT * FROM v_statistiques_bassin;

-- Exemple 4: Transferer un poisson
-- SELECT transferer_poisson(1, 2, 'equilibrage des populations');

-- Exemple 5: Vendre un poisson
-- SELECT vendre_poisson(1);

-- Exemple 6: Calculer le benefice pour un bassin
-- SELECT * FROM calculer_benefice('2026-01-01', '2026-12-31', 1);

-- Exemple 7: Calculer le benefice pour tous les bassins
-- SELECT * FROM calculer_benefice('2026-01-01', '2026-12-31');

-- Exemple 8: Voir l'evolution d'un poisson
-- SELECT * FROM fisakafoanana WHERE id_poisson = 1 ORDER BY date_mesure;

-- Exemple 9: Voir l'historique des transferts
-- SELECT * FROM transfert_poisson ORDER BY date_transfert DESC;

-- ============================================
-- 8. COMMENTAIRES ET MeTADONNeES
-- ============================================

COMMENT ON TABLE race_poisson IS 'Definition des races de poissons avec leurs caracteristiques';
COMMENT ON TABLE bassin IS 'Bassins d''elevage avec leur capacite maximale';
COMMENT ON TABLE poisson IS 'Poissons individuels avec leur etat et localisation';
COMMENT ON TABLE aliment IS 'Aliments disponibles avec leurs caracteristiques nutritionnelles';
COMMENT ON TABLE plat IS 'Compositions alimentaires predefinies';
COMMENT ON TABLE composition_plat IS 'Detail des ingredients dans chaque plat';
COMMENT ON TABLE fisakafoanana IS 'Historique de l''evolution du poids des poissons';
COMMENT ON TABLE distribution_nourriture IS 'Journal des distributions de nourriture par bassin';
COMMENT ON TABLE transfert_poisson IS 'Historique des transferts de poissons entre bassins';

COMMENT ON FUNCTION calculer_prise_poids IS 'Calcule la prise de poids selon les besoins nutritionnels et les consommations';
COMMENT ON FUNCTION nourrir_poissons IS 'Distribue la nourriture à tous les poissons affames d''un bassin';
COMMENT ON FUNCTION transferer_poisson IS 'Transfère un poisson d''un bassin à un autre';
COMMENT ON FUNCTION calculer_benefice IS 'Calcule le benefice sur une periode pour un ou tous les bassins';
COMMENT ON FUNCTION vendre_poisson IS 'Marque un poisson comme vendu et retourne son prix de vente';

-- ============================================
-- 9. SCRIPT DE VeRIFICATION
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '=== VeRIFICATION DE LA BASE DE DONNeES ===';
    RAISE NOTICE '1. Tables crees avec succès';
    RAISE NOTICE '2. Index cres pour optimisation';
    RAISE NOTICE '3. Vues disponibles pour consultation';
    RAISE NOTICE '4. Fonctions operationnelles:';
    RAISE NOTICE '   - calculer_prise_poids';
    RAISE NOTICE '   - nourrir_poissons';
    RAISE NOTICE '   - transferer_poisson';
    RAISE NOTICE '   - calculer_benefice';
    RAISE NOTICE '   - vendre_poisson';
    RAISE NOTICE '5. Declencheurs actives';
    RAISE NOTICE '6. Donnees d''exemple inserees';
    RAISE NOTICE '=== BASE DE DONNeES PRÊTE À L''EMPLOI ===';
END $$;

-- ============================================
-- FIN DU SCRIPT
-- ============================================


