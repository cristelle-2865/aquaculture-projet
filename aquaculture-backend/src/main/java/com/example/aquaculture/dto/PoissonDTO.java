package com.example.aquaculture.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class PoissonDTO {
    private Long id;
    private Long raceId;
    private String raceNom;
    private String nom;
    private BigDecimal prixAchat;
    private BigDecimal prixVente;
    private BigDecimal poidsMaximal;
    private BigDecimal capaciteAugmentation;
    private BigDecimal poidsInitial;
    private BigDecimal poidsActuel;
    private LocalDate dateArrivee;
    private LocalDate dateVente;
    private Boolean estRassasie;
    private Boolean estVendu;
    private Boolean estEnVie;
    private Long bassinId;
    private String bassinNom;
    private BigDecimal progression;
    private Boolean pretAVendre;
}

// Create DTO
@Data
class PoissonCreateDTO {
    private Long raceId;
    private String nom;
    private BigDecimal prixAchat;
    private BigDecimal prixVente;
    private BigDecimal poidsMaximal;
    private BigDecimal capaciteAugmentation;
    private BigDecimal poidsInitial;
    private LocalDate dateArrivee;
    private Long bassinId;
}

// Update DTO
@Data
class PoissonUpdateDTO {
    private String nom;
    private BigDecimal poidsActuel;
    private Boolean estRassasie;
    private Boolean estEnVie;
    private Long bassinId;
}

