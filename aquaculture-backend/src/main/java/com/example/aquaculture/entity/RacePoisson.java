package com.example.aquaculture.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;

@Entity
@Table(name = "race_poisson")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RacePoisson {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_race")
    private Integer idRace;
    
    @Column(name = "nom", nullable = false, length = 100)
    private String nom;
    
    @Column(name = "poids_maximum", nullable = false, precision = 10, scale = 2)
    private BigDecimal poidsMaximum;
    
    @Column(name = "capacite_augmentation_poids", nullable = false, precision = 10, scale = 2)
    private BigDecimal capaciteAugmentationPoids;
    
    @Column(name = "poids_initial", nullable = false, precision = 10, scale = 2)
    private BigDecimal poidsInitial;
    
    @Column(name = "besoin_proteines", precision = 10, scale = 2)
    private BigDecimal besoinProteines = BigDecimal.valueOf(2.0);
    
    @Column(name = "besoin_glucides", precision = 10, scale = 2)
    private BigDecimal besoinGlucides = BigDecimal.valueOf(4.0);
    
    @Column(name = "prix_vente", nullable = false, precision = 10, scale = 2)
    private BigDecimal prixVente;
    
    @Column(name = "prix_achat", nullable = false, precision = 10, scale = 2)
    private BigDecimal prixAchat;
}
